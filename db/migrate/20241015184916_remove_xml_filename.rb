class RemoveXmlFilename < ActiveRecord::Migration[7.2]
  def change
    remove_column :ingests, :xml_filename
  end
end
