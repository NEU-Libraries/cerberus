class ChangeSizeIncreaseLimit < ActiveRecord::Migration
  def up
    change_column :aggregated_statistics, :size_increase, :integer, :limit => 8
  end

  def down
    change_column :aggregated_statistics, :size_increase, :integer, :limit => nil
  end
end
