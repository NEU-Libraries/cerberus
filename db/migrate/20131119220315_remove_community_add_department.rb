class RemoveCommunityAddDepartment < ActiveRecord::Migration
  def up
    User.reset_column_information
    remove_column(:users, :community) if User.column_names.include?('community')
    add_column(:users, :department, :string) unless User.column_names.include?('department')
  end

  def down
  end
end
