# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HumanImpressionsQuery do
  let(:conn) { ActiveRecord::Base.connection }
  let(:today) { Date.current }

  def insert_impression(noid:, ip_address:, user_agent:, action: 'view', recorded_at: Time.current.midday)
    cols = { noid:, action:, ip_address:, user_agent:,
             session_id: 's', referrer: 'direct', created_at: recorded_at, updated_at: recorded_at }
    names  = cols.keys.join(', ')
    values = cols.values.map { |v| conn.quote(v) }.join(', ')
    conn.execute("INSERT INTO impressions (#{names}) VALUES (#{values})")
  end

  before do
    UserAgent.create!(ua_string: 'Mozilla/5.0', is_bot: false, classified_at: Time.current)
    UserAgent.create!(ua_string: 'Googlebot',   is_bot: true,  classified_at: Time.current)
  end

  def human_view_count(**kwargs)
    from_where = described_class.new(conn:, window_start: 7.days.ago.beginning_of_day, **kwargs).from_where_sql
    conn.select_value("SELECT count(*) #{from_where}").to_i
  end

  it 'excludes bot user-agents and includes human ones, same as unscoped' do
    insert_impression(noid: 'w1', ip_address: '10.0.0.1', user_agent: 'Mozilla/5.0')
    insert_impression(noid: 'w1', ip_address: '10.0.0.9', user_agent: 'Googlebot')

    expect(human_view_count).to eq(1)
  end

  it 'restricts to the given noids without under-detecting volume abuse repo-wide' do
    original = Rails.application.config.x.cerberus.impression_volume_threshold
    Rails.application.config.x.cerberus.impression_volume_threshold = 2
    ip = '10.0.0.2'
    # 3 requests to noid w2 alone trips the repo-wide volume rule.
    3.times { |i| insert_impression(noid: 'w2', ip_address: ip, user_agent: 'Mozilla/5.0', recorded_at: today.to_time.midday - i.minutes) }
    insert_impression(noid: 'w3', ip_address: '10.0.0.3', user_agent: 'Mozilla/5.0')

    expect(human_view_count(noids: ['w2'])).to eq(0) # volume-excluded even though scoped
    expect(human_view_count(noids: ['w3'])).to eq(1)
    expect(human_view_count(noids: ['does-not-exist'])).to eq(0)
  ensure
    Rails.application.config.x.cerberus.impression_volume_threshold = original
  end

  it 'treats an empty noid list as matching nothing, not everything' do
    insert_impression(noid: 'w1', ip_address: '10.0.0.1', user_agent: 'Mozilla/5.0')

    expect(human_view_count(noids: [])).to eq(0)
  end

  it 'respects an exclusive range_end upper bound' do
    insert_impression(noid: 'w1', ip_address: '10.0.0.1', user_agent: 'Mozilla/5.0', recorded_at: 2.days.ago.midday)
    insert_impression(noid: 'w1', ip_address: '10.0.0.5', user_agent: 'Mozilla/5.0', recorded_at: Time.current)

    from_where = described_class.new(conn:, window_start: 7.days.ago.beginning_of_day,
                                     range_end: 1.day.ago.beginning_of_day).from_where_sql
    expect(conn.select_value("SELECT count(*) #{from_where}").to_i).to eq(1)
  end
end
