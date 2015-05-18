class CreateLoadReports < ActiveRecord::Migration
  def change
    create_table :load_reports do |t|
      t.string :name
      t.string :email
      t.string :loader_name
      t.string :time
      t.integer :number_of_files

      t.timestamps
    end
  end
end
