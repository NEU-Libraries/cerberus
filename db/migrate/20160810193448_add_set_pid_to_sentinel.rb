class AddSetPidToSentinel < ActiveRecord::Migration
  def change
    add_column :sentinels, :set_pid, :string
  end
end
