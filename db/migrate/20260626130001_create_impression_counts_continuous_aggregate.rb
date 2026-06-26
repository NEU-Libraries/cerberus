# frozen_string_literal: true

# The mechanical speed layer (§6): a TimescaleDB continuous aggregate of RAW
# daily counts per (noid, action) — bots included, no rules. Incrementally
# refreshed by TimescaleDB itself. Powers the dashboard's "all traffic" segment
# and total-side of the human/bot toggle; the human-counts layer is derived
# separately (it must filter before aggregating, which a CA can't). The
# timescaledb gem dumps this declaratively into schema.rb so it round-trips.
class CreateImpressionCountsContinuousAggregate < ActiveRecord::Migration[8.1]
  # CREATE MATERIALIZED VIEW ... WITH (timescaledb.continuous) and the refresh
  # policy cannot run inside a transaction block.
  disable_ddl_transaction!

  def up
    create_continuous_aggregate(
      :impression_counts_by_day,
      query: <<~SQL,
        SELECT noid,
               action,
               time_bucket('1 day', created_at) AS day,
               count(*) AS impressions
        FROM impressions
        GROUP BY noid, action, day
      SQL
      refresh_policies: {
        start_offset:      "INTERVAL '7 days'",
        end_offset:        "INTERVAL '1 hour'",
        schedule_interval: "INTERVAL '1 hour'"
      }
    )
  end

  def down
    drop_continuous_aggregate(:impression_counts_by_day)
  end
end
