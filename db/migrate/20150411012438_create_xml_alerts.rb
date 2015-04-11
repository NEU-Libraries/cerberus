class CreateXmlAlerts < ActiveRecord::Migration
  def change
    create_table :xml_alerts do |t|
      t.string :pid
      t.string :name
      t.string :email
      t.string :title
      t.string :old_file_str
      t.string :new_file_str
      t.string :diff

      t.timestamps
    end
  end
end
