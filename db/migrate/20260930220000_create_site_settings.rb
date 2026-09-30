# frozen_string_literal: true

class CreateSiteSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :site_settings do |t|
      # A closed set of names, declared in SiteSetting::KEYS, so a typo fails
      # validation rather than writing a setting nothing reads.
      t.string :key, null: false
      t.text :value

      t.timestamps
    end

    # Every read is one key.
    add_index :site_settings, :key, unique: true
  end
end
