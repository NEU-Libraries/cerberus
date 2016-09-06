class AddEmailToSentinel < ActiveRecord::Migration
  def change
    add_column :sentinels, :email, :string
  end
end
