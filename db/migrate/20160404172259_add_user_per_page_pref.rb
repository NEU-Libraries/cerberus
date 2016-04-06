class AddUserPerPagePref < ActiveRecord::Migration
  def up
    add_column :users, :per_page_pref, :integer, :default => 10
  end

  def down
    remove_column :users, :per_page_pref
  end
end
