class CreateUploadAlerts < ActiveRecord::Migration
  def change
    create_table :upload_alerts do |t|
      t.string :type
      t.string :title
      t.string :depositor_name
      t.string :depositor_email

      t.timestamps
    end
    add_index :upload_alerts, :type
  end
end
