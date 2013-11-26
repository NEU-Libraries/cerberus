class ChangeNameToFullName < ActiveRecord::Migration
  def up
    rename_column :users, :name, :full_name
  end

  def down
  end
end
