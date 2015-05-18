class AddLoadReportIdToImageReport < ActiveRecord::Migration
  def change
    add_column :image_reports, :load_report_id, :integer
  end
end
