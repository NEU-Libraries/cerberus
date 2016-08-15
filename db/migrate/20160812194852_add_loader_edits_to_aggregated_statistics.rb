class AddLoaderEditsToAggregatedStatistics < ActiveRecord::Migration
  def up
    add_column :aggregated_statistics, :spreadsheet_load_edits, :integer, :default => 0
    add_column :aggregated_statistics, :xml_load_edits, :integer, :default => 0
  end

  def down
    remove_column :aggregated_statistics, :spreadsheet_load_edits
    remove_column :aggregated_statistics, :xml_load_edits
  end
end
