class AddNuidToUsers < ActiveRecord::Migration
  def change
    add_column :users, :nuid, :string
  end
end
