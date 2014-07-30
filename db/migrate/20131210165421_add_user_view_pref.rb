class AddUserViewPref < ActiveRecord::Migration
  def change
    add_column :users, :view_pref, :string, :defualt => "list"
  end
end
