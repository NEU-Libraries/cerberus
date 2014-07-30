class CreateDrsImpressions < ActiveRecord::Migration
  def up
    create_table :drs_impressions do |t| 
      t.string :pid
      t.string :session_id
    end
    add_index :drs_impressions, :pid
  end

  def down
    drop_table :drs_impressions
  end
end
