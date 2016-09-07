class AddCoreFileToSentinels < ActiveRecord::Migration
  def change
    add_column :sentinels, :core_file, :text
  end
end
