# frozen_string_literal: true

require 'rails_helper'

# Confirms the continuous aggregate round-tripped from schema.rb into the test
# DB (the gem-declared create_continuous_aggregate ran on schema load). If the
# CA didn't load, this is the canary.
RSpec.describe ImpressionCountByDay do
  it 'is registered as a TimescaleDB continuous aggregate' do
    count = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT count(*) FROM timescaledb_information.continuous_aggregates
      WHERE view_name = 'impression_counts_by_day'
    SQL

    expect(count).to eq(1)
  end

  it 'is read-only' do
    expect(described_class.new.readonly?).to be(true)
  end
end
