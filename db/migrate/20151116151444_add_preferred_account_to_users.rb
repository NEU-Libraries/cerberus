class AddPreferredAccountToUsers < ActiveRecord::Migration
  def change
    add_column :users, :account_pref, :string, :default => ""
    add_column :users, :multiple_accounts, :boolean, :default => false
  end
end
