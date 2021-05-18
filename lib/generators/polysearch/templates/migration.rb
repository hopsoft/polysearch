# frozen_string_literal: true

class AddPolysearch < ActiveRecord::Migration<%= migration_version %>
  def change
    enable_extension :pg_trgm

    create_table :polysearches, primary_key: [:id, :searchable_type], options: "PARTITION BY HASH (searchable_type)" do |t|
      t.uuid :id, null: false, default: "gen_random_uuid()"
      t.string :searchable_type, null: false
      t.<%= searchable_id_datatype %> :searchable_id, null: false
      t.text :words
      t.tsvector :value
      t.timestamps

      t.index [:searchable_type, :searchable_id], unique: true
      t.index :words, using: :gin, opclass: :gin_trgm_ops
      t.index :value, using: :gin
      t.index :created_at
      t.index :updated_at
    end

    reversible do |dir|
      dir.up do
        execute "CREATE TABLE polysearches_01 PARTITION OF polysearches FOR VALUES WITH (MODULUS 4, REMAINDER 0);"
        execute "CREATE TABLE polysearches_02 PARTITION OF polysearches FOR VALUES WITH (MODULUS 4, REMAINDER 1);"
        execute "CREATE TABLE polysearches_03 PARTITION OF polysearches FOR VALUES WITH (MODULUS 4, REMAINDER 2);"
        execute "CREATE TABLE polysearches_04 PARTITION OF polysearches FOR VALUES WITH (MODULUS 4, REMAINDER 3);"
      end
      dir.down do
        drop_table :polysearches_01
        drop_table :polysearches_02
        drop_table :polysearches_03
        drop_table :polysearches_04
      end
    end
  end
end
