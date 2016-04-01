class CreateAggregatedStatistics < ActiveRecord::Migration
  def up
    create_table :aggregated_statistics do |t|
      t.string :type
      t.string :pid
      t.integer :views, :default => 0
      t.integer :downloads, :default => 0
      t.integer :streams, :default => 0
      t.integer :loader_uploads, :default => 0
      t.integer :user_uploads, :default => 0
      t.integer :form_edits, :default => 0
      t.integer :xml_edits, :default => 0
      t.integer :size_increase, :default => 0
      t.datetime :processed_at
      t.timestamp
    end
  end

  def down
    drop_table :aggregated_statistics
  end
end
