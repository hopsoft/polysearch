# frozen_string_literal: true

module Polysearch
  module Searchable
    extend ActiveSupport::Concern

    module ClassMethods
      def ngrams(value, min: 1, max: 24)
        value = value.to_s
        Set.new.tap do |set|
          (min..max).each do |num|
            value.scan(/\w{#{num}}/).each { |item| set << item }
          end
        end.to_a
      end

      def fts_words(value)
        Loofah.fragment(value.to_s).scrub!(:whitewash).to_text.gsub(/\W/, " ").squeeze(" ").downcase.split
      end

      def fts_string(value)
        value = fts_words(value).join(" ")
        value = value.chop while value.bytes.size > 2046
        value
      end

      def sanitize_sql_value(value)
        sanitize_sql_array ["?", value]
      end
    end

    delegate :ngrams, :fts_words, :fts_string, :sanitize_sql_value, to: "self.class"
    delegate :quote_column_name, to: "self.class.connection"

    included do
      has_one :polysearch, as: :searchable, class_name: "Polysearch::Record", inverse_of: "searchable"
      after_destroy :destroy_polysearch

      scope :polysearch, ->(value) {
        if value.blank?
          all
        else
          fts_rank_alias = "#{table_name.singularize}_fts_rank"
          similarity_rank_alias = "#{table_name.singularize}_similarity_rank"

          fts = Polysearch::Record
            .select_fts_rank(value, :searchable_id, rank_alias: fts_rank_alias)
            .select_similarity_rank(value, :searchable_id, rank_alias: similarity_rank_alias)
            .where(searchable_type: name)
            .fts(value).or(Polysearch::Record.similar(value))

          query = <<~SQL
            SELECT searchables.*, fts.#{fts_rank_alias}, fts.#{similarity_rank_alias} from (#{fts.to_sql}) fts
            LEFT JOIN LATERAL (select * from #{table_name} WHERE id = fts.searchable_id) searchables ON TRUE
          SQL

          select(Arel.star).from(Arel::Nodes::SqlLiteral.new("(#{query})").as(table_name))
            .reorder(fts_rank_alias => :desc, similarity_rank_alias => :desc)
        end
      }
    end

    def update_polysearch
      tsvectors = to_tsvectors.compact.uniq
      return if tsvectors.blank?
      tsvectors.pop while tsvectors.size > 500
      tsvectors.concat similarity_words_tsvectors
      tsvector = tsvectors.join(" || ")
      fts = Polysearch::Record.where(searchable: self).first_or_create
      fts.update_value tsvector
      fts.update_columns words: similarity_words.join(" ")
    end

    # Polysearch::Searchable#to_tsvectors is abstract... a noop by default
    # it must be implemented in including ActiveRecord models if this behavior is desired
    #
    # Example:
    #
    # def to_tsvectors
    #   []
    #     .then { |result| result << make_tsvector(EXAMPLE_COLUMN_OR_PROPERTY, weight: "A") }
    #     .then { |result| EXAMPLE_TAGS_COLUMN.each_with_object(result) { |tag, memo| memo << make_tsvector(tag, weight: "B") } }
    # end
    #
    def to_tsvectors
      []
    end

    def similarity_words
      tsvectors = to_tsvectors.compact.uniq
      return [] if tsvectors.blank?
      tsvector = tsvectors.join(" || ")

      ts_stat = Arel::Nodes::NamedFunction.new("ts_stat", [
        Arel::Nodes::SqlLiteral.new(sanitize_sql_value("SELECT #{tsvector}"))
      ])
      length = Arel::Nodes::NamedFunction.new("length", [Arel::Nodes::SqlLiteral.new(quote_column_name(:word))])
      query = self.class.select(:word).from(ts_stat.to_sql).where(length.gteq(3)).to_sql
      result = self.class.connection.execute(query)
      result.values.flatten
    end

    def similarity_ngrams
      similarity_words.each_with_object(Set.new) do |word, memo|
        ngrams(word).each { |ngram| memo << ngram }
      end.to_a.sort_by(&:length)
    end

    def similarity_words_tsvectors(weight: "D")
      similarity_ngrams.each_with_object([]) do |ngram, memo|
        memo << make_tsvector(ngram, weight: weight)
      end
    end

    protected

    def make_tsvector(value, weight: "D")
      value = fts_string(value).gsub(/\W/, " ").squeeze.downcase
      return nil if value.blank?
      to_tsv = Arel::Nodes::NamedFunction.new("to_tsvector", [
        Arel::Nodes::SqlLiteral.new("'simple'"),
        Arel::Nodes::SqlLiteral.new(sanitize_sql_value(value))
      ])
      setweight = Arel::Nodes::NamedFunction.new("setweight", [
        to_tsv,
        Arel::Nodes::SqlLiteral.new(sanitize_sql_value(weight))
      ])
      setweight.to_sql
    end

    private

    def destroy_polysearch
      polysearch&.destroy
    end
  end
end
