class AddPidToUploadAlerts < ActiveRecord::Migration
  def change
    add_column :upload_alerts, :pid, :string
  end
end
