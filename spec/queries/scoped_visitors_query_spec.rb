# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScopedVisitorsQuery do
  let(:conn) { ActiveRecord::Base.connection }
  let(:today) { Date.current }
  let(:range) { (today - 1)..today }

  def insert_impression(noid:, ip_address:, user_agent: 'Mozilla/5.0', recorded_at: Time.current.midday)
    cols = { noid:, action: 'view', ip_address:, user_agent:,
             session_id: 's', referrer: 'direct', created_at: recorded_at, updated_at: recorded_at }
    names  = cols.keys.join(', ')
    values = cols.values.map { |v| conn.quote(v) }.join(', ')
    conn.execute("INSERT INTO impressions (#{names}) VALUES (#{values})")
  end

  before do
    UserAgent.create!(ua_string: 'Mozilla/5.0', is_bot: false, classified_at: Time.current)
    UserAgent.create!(ua_string: 'Googlebot',   is_bot: true,  classified_at: Time.current)
  end

  it 'returns an empty series without querying when the noid list is empty' do
    expect(ActiveRecord::Base.connection).not_to receive(:select_rows)
    expect(described_class.new(range:, segment: :human, noids: []).series).to eq({})
  end

  it 'counts distinct human visitors for the given noids only (human segment)' do
    insert_impression(noid: 'w1', ip_address: '10.0.0.1')
    insert_impression(noid: 'w1', ip_address: '10.0.0.5')
    insert_impression(noid: 'w1', ip_address: '10.0.0.9', user_agent: 'Googlebot')
    insert_impression(noid: 'w2', ip_address: '10.0.0.1') # different noid, out of scope

    series = described_class.new(range:, segment: :human, noids: ['w1']).series

    expect(series[today]).to eq(2)
  end

  it 'counts raw distinct visitors (bots included) for the all-traffic segment' do
    insert_impression(noid: 'w1', ip_address: '10.0.0.1')
    insert_impression(noid: 'w1', ip_address: '10.0.0.9', user_agent: 'Googlebot')

    series = described_class.new(range:, segment: :all, noids: ['w1']).series

    expect(series[today]).to eq(2)
  end

  it 'excludes noids outside the requested scope' do
    insert_impression(noid: 'w1', ip_address: '10.0.0.1')
    insert_impression(noid: 'w2', ip_address: '10.0.0.2')

    series = described_class.new(range:, segment: :human, noids: ['w1']).series

    expect(series[today]).to eq(1)
  end
end
