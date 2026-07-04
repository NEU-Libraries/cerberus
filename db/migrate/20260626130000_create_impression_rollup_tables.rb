# frozen_string_literal: true

# The derived reporting layer over the raw impressions hypertable (all ordinary
# tables, populated by scheduled jobs — see RollupImpressionsJob /
# RollupContainerImpressionsJob).
#
# - impression_daily_counts: the HUMAN-counts reporting target, per
#   (noid, action, day). Derived from raw with the §9 rules applied (UA bot
#   filter + volume exclusion + allowlist) — the dashboard's primary read.
# - impression_container_daily_counts: the same shape keyed by a container's
#   noid, summed down the structural-home tree (top-N collections/communities).
# - impression_daily_visitors: the repo-wide distinct-non-bot-IP metric per day
#   (§10 "unique visitors"), which DISTINCT can't sum across days so it's stored
#   per-day at derivation time.
class CreateImpressionRollupTables < ActiveRecord::Migration[8.1]
  def change
    create_table :impression_daily_counts, id: false do |t|
      t.string  :noid,   null: false
      t.string  :action, null: false
      t.date    :day,    null: false
      t.integer :count,  null: false, default: 0
    end
    add_index :impression_daily_counts, %i[noid action day], unique: true
    add_index :impression_daily_counts, %i[action day]

    create_table :impression_container_daily_counts, id: false do |t|
      t.string  :noid,   null: false
      t.string  :action, null: false
      t.date    :day,    null: false
      t.integer :count,  null: false, default: 0
    end
    add_index :impression_container_daily_counts, %i[noid action day], unique: true
    add_index :impression_container_daily_counts, %i[action day]

    create_table :impression_daily_visitors, id: false do |t|
      t.date    :day,             null: false
      t.integer :unique_visitors, null: false, default: 0
    end
    add_index :impression_daily_visitors, :day, unique: true
  end
end
