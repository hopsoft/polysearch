# frozen_string_literal: true

# require "rails/generators/base"

module Polysearch
  module Generators
    class MigrationGenerator < Rails::Generators::Base
      desc "Copy polysearch database migrations into your project"
      argument :searchable_id_datatype, type: :string, default: "bigint"
      source_root File.expand_path("../templates", __FILE__)

      def copy_polysearch_migration
        template "migration.rb", "db/migrate/#{timestamp}_add_polysearch.rb",
          searchable_id_datatype: searchable_id_datatype,
          migration_version: migration_version
      end

      private

      def timestamp
        DateTime.current.strftime "%Y%m%d%H%M%S"
      end

      def migration_version
        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      end
    end
  end
end
