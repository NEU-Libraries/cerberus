# frozen_string_literal: true

require 'rails_helper'

# The test database is built from db/schema.rb, so these examples fail when the
# dump loses a TimescaleDB object or policy. See docs/analytics.md.
RSpec.describe 'impressions hypertable', type: :model do
  let(:connection) { ActiveRecord::Base.connection }

  def policy_count(proc_name, object)
    connection.select_value(<<~SQL.squish)
      SELECT count(*) FROM timescaledb_information.jobs j
      LEFT JOIN timescaledb_information.continuous_aggregates c
        ON c.materialization_hypertable_name = j.hypertable_name
      WHERE j.proc_name = #{connection.quote(proc_name)}
        AND COALESCE(c.view_name, j.hypertable_name) = #{connection.quote(object)}
    SQL
  end

  it 'refreshes the impression_counts_by_day aggregate on a schedule' do
    expect(policy_count('policy_refresh_continuous_aggregate', 'impression_counts_by_day')).to eq(1)
  end

  it 'is registered as a TimescaleDB hypertable' do
    count = connection.select_value(<<~SQL.squish)
      SELECT count(*) FROM timescaledb_information.hypertables
      WHERE hypertable_name = 'impressions'
    SQL

    expect(count).to eq(1)
  end

  it 'has the per-object, throttle, and trend indexes' do
    columns = connection.indexes(:impressions).map(&:columns)

    expect(columns).to include(%w[noid created_at])
      .and include(%w[noid action ip_address created_at])
      .and include(%w[action created_at])
  end
end
