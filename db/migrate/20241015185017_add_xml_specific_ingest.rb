class AddXmlSpecificIngest < ActiveRecord::Migration[7.2]
  def change
    create_table :xml_ingests do |t|
      t.string :xml_filename, null: false

      t.timestamps
    end
  end
end
