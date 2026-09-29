# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImpressionDay do
  it 'names the IANA zone Postgres resolves daylight saving with' do
    expect(described_class.zone).to eq('America/New_York')
  end

  it 'reads a UTC timestamp as its Eastern date in SQL' do
    date = ActiveRecord::Base.connection.select_value(
      "SELECT #{described_class.of("'2026-07-10 02:30:00'::timestamp")}"
    )
    expect(date.to_s).to eq('2026-07-09')
  end

  # 8 March 2026 is the spring-forward day: Eastern midnight moves from
  # UTC-5 to UTC-4, so that local day is only 23 hours long.
  it "bounds a range of Eastern days by each day's own midnight, across daylight saving" do
    bounds = described_class.utc_bounds(Date.new(2026, 3, 8)..Date.new(2026, 3, 8))

    expect(bounds.begin).to eq(Time.utc(2026, 3, 8, 5))
    expect(bounds.end).to eq(Time.utc(2026, 3, 9, 4))
    expect(bounds).to be_exclude_end
  end
end
