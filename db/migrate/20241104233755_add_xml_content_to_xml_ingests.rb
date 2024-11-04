class AddXmlContentToXmlIngests < ActiveRecord::Migration[7.2]
  def change
    add_column :xml_ingests, :xml_content, :text
  end
end
