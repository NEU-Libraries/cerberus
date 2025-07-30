class AddColumnsToSentinel < ActiveRecord::Migration
  def change
    add_column :sentinels, :epub, :text
    add_column :sentinels, :dataset, :text
    add_column :sentinels, :image_thumbnail, :text
  end
end
