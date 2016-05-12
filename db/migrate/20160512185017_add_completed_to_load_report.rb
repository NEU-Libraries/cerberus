class AddCompletedToLoadReport < ActiveRecord::Migration
  def up
    add_column :load_reports, :completed, :boolean, :default => false
  end

  def down
    remove_column :load_reports, :completed
  end
end
