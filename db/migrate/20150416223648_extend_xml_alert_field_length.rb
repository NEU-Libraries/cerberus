class ExtendXmlAlertFieldLength < ActiveRecord::Migration
  def self.up
      change_table :xml_alerts do |t|
        t.change :old_file_str, :text, :limit => 4294967295
        t.change :new_file_str, :text, :limit => 4294967295
        t.change :diff, :text, :limit => 4294967295
      end
    end
    def self.down
      change_table :xml_alerts do |t|
        t.change :old_file_str, :text
        t.change :new_file_str, :text
        t.change :diff, :text
      end
    end
end
