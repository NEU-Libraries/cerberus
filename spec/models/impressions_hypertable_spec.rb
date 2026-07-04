# frozen_string_literal: true

require 'rails_helper'

# Confirms the impressions table is a real TimescaleDB hypertable with the
# capture/throttle indexes. This depends on the test DB loading from
# db/structure.sql (schema_format = :sql) with the extension active — i.e. the
# developer has recreated the stack on the timescale image and run db:migrate.
# If pg_dump's hypertable round-trip turns out to be lossy, the first example
# fails here as the canary (see the plan's Risk #3).
RSpec.describe 'impressions hypertable', type: :model do
  let(:connection) { ActiveRecord::Base.connection }

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
