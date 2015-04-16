class ChangeXmlAlertFieldTypes < ActiveRecord::Migration
  def self.up
      change_table :xml_alerts do |t|
        t.change :old_file_str, :text
        t.change :new_file_str, :text
        t.change :diff, :text
      end
    end
    def self.down
      change_table :xml_alerts do |t|
        t.change :old_file_str, :string
        t.change :new_file_str, :string
        t.change :diff, :string
      end
    end
end
