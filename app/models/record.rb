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

    scope :select_fts_rank, ->(value, *selects, rank_alias: nil) {
      value = value.to_s.gsub(/\W/, " ").squeeze(" ").downcase.strip
      value = Arel::Nodes::SqlLiteral.new(sanitize_sql_array(["?", value.to_s]))
      plainto_tsquery = Arel::Nodes::NamedFunction.new("plainto_tsquery", [Arel::Nodes::SqlLiteral.new("'simple'"), value])
      ts_rank = Arel::Nodes::NamedFunction.new("ts_rank", [arel_table[:value], plainto_tsquery])

      rank_alias ||= "fts_rank"
      selects << Arel.star if selects.blank?
      selects << ts_rank.as(rank_alias)
      select(*selects).order("#{rank_alias} desc")
    }

    scope :fts, ->(value) {
      value = value.to_s.gsub(/\W/, " ").squeeze(" ").downcase.strip
      value = Arel::Nodes::SqlLiteral.new(sanitize_sql_array(["?", value.to_s]))
      plainto_tsquery = Arel::Nodes::NamedFunction.new("plainto_tsquery", [Arel::Nodes::SqlLiteral.new("'simple'"), value])
      where(Arel::Nodes::InfixOperation.new("@@", arel_table[:value], plainto_tsquery))
    }

    scope :select_similarity_rank, ->(value, *selects, rank_alias: nil) {
      value = value.to_s.gsub(/\W/, " ").squeeze(" ").downcase.strip
      value = Arel::Nodes::SqlLiteral.new(sanitize_sql_array(["?", value.to_s]))

      rank_alias ||= "similarity_rank"
      selects << Arel.star if selects.blank?
      selects << Arel::Nodes::NamedFunction.new("similarity", [arel_table[:words], value]).as(rank_alias)
      select(*selects).order("#{rank_alias} desc")
    }

    scope :similar, ->(value, range: 0.01) {
      value = value.to_s.gsub(/\W/, " ").squeeze(" ").downcase.strip
      value = Arel::Nodes::SqlLiteral.new(sanitize_sql_array(["?", value.to_s]))
      where Arel::Nodes::NamedFunction.new("similarity", [arel_table[:words], value]).gteq(range)
    }

    # additional config (i.e. accepts_nested_attribute_for etc...) ..............
    self.table_name = "polysearches"
    self.primary_key = :id

    # class methods .............................................................
    class << self
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
