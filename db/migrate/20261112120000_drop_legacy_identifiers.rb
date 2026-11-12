# frozen_string_literal: true

# Atlas holds each object's v1 pid, and LegacyController asks Atlas for it, so
# nothing reads this table. The block keeps the drop reversible.
class DropLegacyIdentifiers < ActiveRecord::Migration[8.0]
  def change
    drop_table :legacy_identifiers do |t|
      t.string :pid, null: false
      t.string :noid, null: false
      t.string :object_type, null: false
      t.timestamps

      t.index :pid, unique: true
      t.index :noid
    end
  end
end
