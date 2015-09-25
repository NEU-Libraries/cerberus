class AddModifiedToImageReport < ActiveRecord::Migration
  def change
    add_column :image_reports, :modified, :boolean, :default => false
  end
end
