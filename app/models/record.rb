# frozen_string_literal: true

# == Schema Information
#
# Table name: polysearches
#
#  id              :uuid             not null, primary key
#  searchable_type :string           not null
#  value           :tsvector
#  words           :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  searchable_id   :uuid             not null
#
# Indexes
#
#  index_polysearches_on_created_at                         (created_at)
#  index_polysearches_on_searchable_type_and_searchable_id  (searchable_type,searchable_id) UNIQUE
#  index_polysearches_on_updated_at                         (updated_at)
#  index_polysearches_on_value                              (value) USING gin
#  index_polysearches_on_words                              (words) USING gin
#
module Polysearch
  class Record < ActiveRecord::Base
    # extends ...................................................................
    # includes ..................................................................

    # relationships .............................................................
    belongs_to :searchable, polymorphic: true, inverse_of: "polysearch"

    # validations ...............................................................
    # callbacks .................................................................

    # scopes ....................................................................

    scope :select_full_text_search_rank, ->(value, *selects) {
      plainto_tsquery = Arel::Nodes::NamedFunction.new("plainto_tsquery", [Arel::Nodes::SqlLiteral.new("'simple'"), arel_search_value(value)])
      ts_rank = Arel::Nodes::NamedFunction.new("ts_rank", [arel_table[:value], plainto_tsquery])
      selects << Arel.star if selects.blank?
      selects << ts_rank.as("search_rank")
      select(*selects).reorder("search_rank desc")
    }

    scope :full_text_search, ->(value) {
      if value.blank?
        all
      else
        plainto_tsquery = Arel::Nodes::NamedFunction.new("plainto_tsquery", [Arel::Nodes::SqlLiteral.new("'simple'"), arel_search_value(value)])
        where(Arel::Nodes::InfixOperation.new("@@", arel_table[:value], plainto_tsquery))
      end
    }

    scope :select_similarity_rank, ->(value, *selects) {
      similarity = Arel::Nodes::NamedFunction.new("similarity", [arel_table[:words], arel_search_value(value)])
      selects << Arel.star if selects.blank?
      selects << similarity.as("search_rank")
      select(*selects).order("search_rank desc")
    }

    scope :similarity_search, ->(value) {
      if value.blank?
        all
      else
        where Arel::Nodes::NamedFunction.new("similarity", [arel_table[:words], arel_search_value(value)]).gt(0)
      end
    }

    scope :polysearch, ->(value) {
      if value.blank?
        all
      else
        full_text_search(value).exists? ?
          select_full_text_search_rank(value).full_text_search(value) :
          select_similarity_rank(value).similarity_search(value)
      end
    }

    # additional config (i.e. accepts_nested_attribute_for etc...) ..............
    self.table_name = "polysearches"
    self.primary_key = :id

    # class methods .............................................................
    class << self
      def arel_search_value(value)
        value = value.to_s.gsub(/\W/, " ").squeeze(" ").downcase.strip
        Arel::Nodes::SqlLiteral.new(sanitize_sql_array(["?", value]))
      end
    end

    # public instance methods ...................................................

    def update_value(tsvector_sql)
      sql = <<~SQL
        UPDATE polysearches
        SET value = (#{tsvector_sql})
        WHERE searchable_type = :searchable_type
        AND searchable_id = :searchable_id;
      SQL
      self.class.connection.execute self.class.sanitize_sql_array([
        sql,
        searchable_type: searchable_type,
        searchable_id: searchable_id
      ])
    end

    # protected instance methods ................................................

    # private instance methods ..................................................
  end
end
