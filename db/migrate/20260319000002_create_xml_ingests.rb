# frozen_string_literal: true

class CreateXmlIngests < ActiveRecord::Migration[8.0]
  def change
    create_table :xml_ingests do |t|
      t.references :load_report, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :work_pid
      t.string :source_filename

      t.timestamps
    end
  end
end
