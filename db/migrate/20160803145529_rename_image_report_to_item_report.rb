class RenameImageReportToItemReport < ActiveRecord::Migration
  def up
    rename_table :image_reports, :item_reports
  end

  def down
    rename_table :item_reports, :image_reports
  end
end
