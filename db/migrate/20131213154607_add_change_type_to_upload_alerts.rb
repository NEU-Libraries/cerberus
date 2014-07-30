class AddChangeTypeToUploadAlerts < ActiveRecord::Migration
  def change
    add_column :upload_alerts, :change_type, :string
  end
end
