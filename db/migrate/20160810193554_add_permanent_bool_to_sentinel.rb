class AddPermanentBoolToSentinel < ActiveRecord::Migration
  def change
    add_column :sentinels, :permanent, :boolean
  end
end
