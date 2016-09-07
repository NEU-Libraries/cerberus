class AddPreviewBooleanToItemReports < ActiveRecord::Migration
  def up
    add_column :item_reports, :preview_file, :boolean, :default=>false
  end
  def down
    remove_column :item_reports, :preview_file
  end
end
