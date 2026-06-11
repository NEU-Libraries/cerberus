# frozen_string_literal: true

class AddKindToLoaders < ActiveRecord::Migration[8.0]
  def change
    # Discriminates which ingest pipeline a loader drives. 0 = iptc keeps the
    # existing marcom loader on its current behaviour; 1 = xml is the new
    # manifest-driven MODS loader. Backed by a Loader.enum in the model.
    add_column :loaders, :kind, :integer, null: false, default: 0
  end
end
