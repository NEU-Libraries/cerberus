# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImpressionSeeder do
  subject(:seeder) { described_class.new(days: 30) }

  # Keep the seed off Solr and the TimescaleDB continuous aggregate; the
  # human-counts rollup (pure SQL) runs for real so the derivation is genuinely
  # exercised against the rows the seeder inserts.
  before do
    allow(seeder).to receive(:fetch_work_noids).and_return(%w[work-alpha work-beta])
    allow(RollupContainerImpressionsJob).to receive(:perform_now)
    allow(seeder).to receive(:refresh_continuous_aggregate)
  end

  it 'inserts raw view/download impressions keyed on the indexed Works' do
    seeder.call

    expect(Impression.count).to be_positive
    expect(Impression.distinct.pluck(:noid)).to all(be_in(%w[work-alpha work-beta]))
    expect(Impression.distinct.pluck(:action)).to all(be_in(%w[view download]))
    expect(Impression.where(created_at: ..31.days.ago)).not_to exist
  end

  it 'records the user agents with a human/bot split' do
    seeder.call

    expect(UserAgent.where(is_bot: false).count).to eq(described_class::HUMAN_AGENTS.size)
    expect(UserAgent.where(is_bot: true).count).to eq(described_class::BOT_AGENTS.size)
  end

  it 'derives the human-counts rollup, filtering bots out of the raw total' do
    seeder.call

    human_total = ImpressionDailyCount.sum(:count)
    expect(human_total).to be_positive
    expect(human_total).to be <= Impression.count
  end

  it 'clears prior raw rows before re-seeding so re-runs stay representative' do
    expect(Impression).to receive(:delete_all).and_call_original
    seeder.call
  end

  it 'no-ops when Solr has no Works yet' do
    allow(seeder).to receive(:fetch_work_noids).and_return([])

    expect(seeder.call).to eq(0)
    expect(Impression.count).to eq(0)
  end

  it 'reads Work noids from the Solr alternate-id field' do
    real = described_class.new(days: 1)
    allow(real).to receive(:refresh_continuous_aggregate)
    response = instance_double(Blacklight::Solr::Response,
                               documents: [solr_doc('id-work-x'), solr_doc('id-work-y')])
    allow(Blacklight).to receive(:default_index).and_return(instance_double(Blacklight::Solr::Repository, search: response))

    real.call

    expect(Impression.distinct.pluck(:noid)).to all(be_in(%w[work-x work-y]))
  end

  it 'treats the continuous-aggregate refresh as best-effort (rescues inside a transaction)' do
    # RSpec wraps each example in a transaction, where refresh_continuous_aggregate
    # is illegal; the seed must swallow that rather than abort.
    expect { described_class.new.send(:refresh_continuous_aggregate) }.not_to raise_error
  end

  def solr_doc(alt_id)
    doc = instance_double(SolrDocument)
    allow(doc).to receive(:[]).with('alternate_ids_ssim').and_return([alt_id])
    doc
  end
end
