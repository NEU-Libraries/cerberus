class AddEditorToUploadAlert < ActiveRecord::Migration
  def self.up
    add_column :upload_alerts, :editor_nuid, :string
  end
  def self.down
    remove_column :upload_alerts, :editor_nuid, :string
  end
end
