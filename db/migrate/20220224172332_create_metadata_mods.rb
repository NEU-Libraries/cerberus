class CreateMetadataMODS < ActiveRecord::Migration[7.0]
  def change
    create_table :metadata_mods do |t|
      t.jsonb :json_attributes
      t.timestamps
    end
  end
end
