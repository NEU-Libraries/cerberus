# frozen_string_literal: true

class CreateLoadReports < ActiveRecord::Migration[8.0]
  def change
    create_table :load_reports do |t|
      t.integer :status, null: false, default: 0
      t.string :source_filename
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
  end
end
