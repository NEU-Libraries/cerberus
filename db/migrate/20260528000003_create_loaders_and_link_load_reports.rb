# frozen_string_literal: true

class CreateLoadersAndLinkLoadReports < ActiveRecord::Migration[8.0]
  def change
    create_table :loaders do |t|
      t.string :slug,            null: false
      t.string :display_name,    null: false
      t.string :group,           null: false
      t.string :root_collection, null: false
      t.timestamps
    end
    add_index :loaders, :slug, unique: true

    add_reference :load_reports, :loader, foreign_key: true
  end
end
