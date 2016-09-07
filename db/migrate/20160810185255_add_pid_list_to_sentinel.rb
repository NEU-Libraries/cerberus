class AddPidListToSentinel < ActiveRecord::Migration
  def change
    add_column :sentinels, :pid_list, :text
  end
end
