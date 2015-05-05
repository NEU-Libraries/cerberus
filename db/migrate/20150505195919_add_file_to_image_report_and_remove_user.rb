class AddFileToImageReportAndRemoveUser < ActiveRecord::Migration
  def self.up
    add_column :image_reports, :original_file, :string
    remove_column :image_reports, :name
    remove_column :image_reports, :email
  end

  def self.down
    remove_column :image_reports, :original_file
    add_column :image_reports, :name, :string
    add_column :image_reports, :email, :string
  end
end
