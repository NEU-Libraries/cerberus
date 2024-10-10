class CreateLoadReports < ActiveRecord::Migration[7.2]
  def change
    create_table :load_reports do |t|
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
  end
end
