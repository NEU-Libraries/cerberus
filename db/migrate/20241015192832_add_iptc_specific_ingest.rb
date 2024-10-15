class AddIptcSpecificIngest < ActiveRecord::Migration[7.2]
  def change
    create_table :iptc_ingests do |t|
      t.string :image_filename, null: false
      t.string :metadata, null: false

      t.timestamps
    end
  end
end
