class AddPreviewPidsToLoadReport < ActiveRecord::Migration
  def change
    add_column :load_reports, :comparison_file_pid, :string, :default => ""
    add_column :load_reports, :preview_file_pid, :string, :default => ""
  end
end
