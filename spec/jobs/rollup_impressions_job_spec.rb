# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RollupImpressionsJob do
  let(:config) { Rails.application.config.x.cerberus }
  let(:today)  { Date.current }

  # Raw insert bypassing the model's 1-hour throttle so we can seed many rows
  # for one (ip, day) — what the volume rule keys on.
  def insert_impression(noid:, ip_address:, user_agent:, action: 'view', recorded_at: Time.current.midday)
    cols = { noid:, action:, ip_address:, user_agent:,
             session_id: 's', referrer: 'direct', created_at: recorded_at, updated_at: recorded_at }
    names  = cols.keys.join(', ')
    values = cols.values.map { |v| ActiveRecord::Base.connection.quote(v) }.join(', ')
    ActiveRecord::Base.connection.execute("INSERT INTO impressions (#{names}) VALUES (#{values})")
  end

  before do
    UserAgent.create!(ua_string: 'Mozilla/5.0', is_bot: false, classified_at: Time.current)
    UserAgent.create!(ua_string: 'Googlebot',   is_bot: true,  classified_at: Time.current)
  end

  it 'counts human rows and excludes bot user-agents' do
    insert_impression(noid: 'w1', ip_address: '10.0.0.1', user_agent: 'Mozilla/5.0')
    insert_impression(noid: 'w1', ip_address: '10.0.0.9', user_agent: 'Googlebot')

    described_class.perform_now

    expect(ImpressionDailyCount.find_by(noid: 'w1', action: 'view', day: today)[:count]).to eq(1)
  end

  it 'excludes volume-offending (ip, day) pairs but rescues the allowlist' do
    original = config.impression_volume_threshold
    config.impression_volume_threshold = 2
    allow_ip = config.impression_ip_allowlist.first

    3.times { |i| insert_impression(noid: 'w2', ip_address: '10.0.0.2', user_agent: 'Mozilla/5.0', recorded_at: today.to_time.midday - i.minutes) }
    3.times { |i| insert_impression(noid: 'w3', ip_address: allow_ip,   user_agent: 'Mozilla/5.0', recorded_at: today.to_time.midday - i.minutes) }

    described_class.perform_now

    expect(ImpressionDailyCount.find_by(noid: 'w2', action: 'view')).to be_nil # volume-excluded
    expect(ImpressionDailyCount.find_by(noid: 'w3', action: 'view')[:count]).to eq(3) # rescued
  ensure
    config.impression_volume_threshold = original
  end

  it 'materializes per-day distinct human visitors' do
    insert_impression(noid: 'w1', ip_address: '10.0.0.1', user_agent: 'Mozilla/5.0')
    insert_impression(noid: 'w4', ip_address: '10.0.0.1', user_agent: 'Mozilla/5.0', action: 'download')
    insert_impression(noid: 'w1', ip_address: '10.0.0.5', user_agent: 'Mozilla/5.0')
    insert_impression(noid: 'w1', ip_address: '10.0.0.9', user_agent: 'Googlebot')

    described_class.perform_now

    expect(ImpressionDailyVisitor.find_by(day: today).unique_visitors).to eq(2)
  end

  it 're-derives idempotently across runs' do
    insert_impression(noid: 'w1', ip_address: '10.0.0.1', user_agent: 'Mozilla/5.0')

    2.times { described_class.perform_now }

    expect(ImpressionDailyCount.where(noid: 'w1', action: 'view', day: today).count).to eq(1)
  end
end
