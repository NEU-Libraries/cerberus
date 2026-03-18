# frozen_string_literal: true

class DropIngestTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :ingests
    drop_table :load_reports
  end
end
