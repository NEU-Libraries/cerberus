class AddValkyrieIdToMetadataMODS < ActiveRecord::Migration[7.0]
  def change
    add_column :metadata_mods, :valkyrie_id, :string
  end
end
