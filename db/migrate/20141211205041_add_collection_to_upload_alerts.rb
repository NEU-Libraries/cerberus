class AddCollectionToUploadAlerts < ActiveRecord::Migration
  def change
    add_column :upload_alerts, :collection_pid, :string
    add_column :upload_alerts, :collection_title, :string
  end
end
