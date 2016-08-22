class AddChangeTypeToItemReports < ActiveRecord::Migration
  def up
    add_column :item_reports, :change_type, :string
  end

  def down
    remove_column :item_reports, :change_type
  end
end
