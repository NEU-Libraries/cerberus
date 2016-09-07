class AddContentModelsToSentinel < ActiveRecord::Migration
  def change
    add_column :sentinels, :audio, :text
    add_column :sentinels, :audio_master, :text
    add_column :sentinels, :image_large, :text
    add_column :sentinels, :image_master, :text
    add_column :sentinels, :image_medium, :text
    add_column :sentinels, :image_small, :text
    add_column :sentinels, :msexcel, :text
    add_column :sentinels, :mspowerpoint, :text
    add_column :sentinels, :msword, :text
    add_column :sentinels, :page, :text
    add_column :sentinels, :pdf, :text
    add_column :sentinels, :text, :text
    add_column :sentinels, :video, :text
    add_column :sentinels, :video_master, :text
    add_column :sentinels, :zip, :text
  end
end
