class AddModifiedCountToLoadReport < ActiveRecord::Migration
  def self.up
    add_column :load_reports, :modified_count, :integer
  end
  def self.down
    remove_column :load_reports, :modified_count, :integer
  end
end
