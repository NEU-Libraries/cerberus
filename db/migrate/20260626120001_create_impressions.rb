# frozen_string_literal: true

# The raw, append-only impressions log — a TimescaleDB hypertable partitioned on
# created_at (~monthly chunks), created via the timescaledb gem's create_table
# `hypertable:` option so it round-trips through schema.rb. Shape mirrors v1
# minus its bot-classification columns (public/processed) and the cart-marker
# `status`: bot verdicts are derived (never stored on the row), and the cart is
# its own session store.
#
# No surrogate primary key (id: false): a hypertable's key must include the
# partition column, and impressions are append-only — never referenced by a
# surrogate id — so the simplest round-trippable shape is no PK at all.
class CreateImpressions < ActiveRecord::Migration[8.1]
  def change
    hypertable_options = {
      time_column: 'created_at',
      chunk_time_interval: '1 month'
    }

    create_table :impressions, id: false, hypertable: hypertable_options do |t|
      t.string :noid, null: false
      t.string :session_id
      t.string :action, null: false
      t.string :ip_address
      t.string :referrer
      t.string :user_agent
      t.timestamps
    end

    # Per-object counts / recent activity.
    add_index :impressions, %i[noid created_at], order: { created_at: :desc }
    # Backs the 1-hour (noid, action, ip) dedup throttle as an index range scan.
    add_index :impressions, %i[noid action ip_address created_at]
    # Global/trend queries by event type.
    add_index :impressions, %i[action created_at]
  end
end
