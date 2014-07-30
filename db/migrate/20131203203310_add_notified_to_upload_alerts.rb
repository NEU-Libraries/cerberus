class AddNotifiedToUploadAlerts < ActiveRecord::Migration
  def change
    add_column :upload_alerts, :notified, :boolean
  end
end
