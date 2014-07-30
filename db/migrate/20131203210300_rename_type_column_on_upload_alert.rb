class RenameTypeColumnOnUploadAlert < ActiveRecord::Migration
  def up
    rename_column :upload_alerts, :type, :content_type
  end

  def down
  end
end
