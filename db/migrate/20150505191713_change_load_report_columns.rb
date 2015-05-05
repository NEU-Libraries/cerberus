class ChangeLoadReportColumns < ActiveRecord::Migration
  def self.up
    add_column :load_reports, :success_count, :integer
    add_column :load_reports, :fail_count, :integer
    add_column :load_reports, :nuid, :integer
    add_column :load_reports, :collection, :string
    remove_column :load_reports, :time
    remove_column :load_reports, :name
    remove_column :load_reports, :email
  end

  def self.down
    remove_column :load_reports, :success_count
    remove_column :load_reports, :fail_count
    remove_column :load_reports, :nuid
    remove_column :load_reports, :collection
    add_column :load_reports, :time, :string
    add_column :load_reports, :name, :string
    add_column :load_reports, :email, :string
  end
end
