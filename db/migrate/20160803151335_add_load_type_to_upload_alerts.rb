class AddLoadTypeToUploadAlerts < ActiveRecord::Migration
  def up
    add_column :upload_alerts, :load_type, :string, :default => ""
  end

  def down
    remove_column :upload_alerts, :load_type
  end
end
