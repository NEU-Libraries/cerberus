class FixTypeColumnName < ActiveRecord::Migration
  def up
    rename_column :aggregated_statistics, :type, :object_type
  end

  def down
    rename_column :aggregated_statistics, :type, :object_type
  end
end
