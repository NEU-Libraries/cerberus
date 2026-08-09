# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailyDigestJob do
  let(:day) { Date.new(2026, 8, 8) }

  # Solr is reachable in this environment, but the stuck-deposit counts depend on
  # whatever else the suite has left in the index. Pinned so the digest's own
  # arithmetic is what these examples measure.
  before do
    allow(Blacklight.default_index).to receive(:search)
      .and_return(instance_double(Blacklight::Solr::Response, total: 3))
  end

  # A request kind needs an actor and a subject; an activity kind needs neither.
  def notice_on(day, kind:, actor: nil, **payload)
    AdminNotice.create!(kind: kind, subject: 'x', occurred_on: day, actor_nuid: actor,
                        subject_noid: ('x1' if actor), payload: payload)
  end

  describe 'the counts' do
    it 'counts the requests made on the day, and not those made on another' do
      notice_on(day, kind: 'request_withdraw', actor: '000000010')
      notice_on(day, kind: 'request_move', actor: '000000010')
      notice_on(day - 1, kind: 'request_restrict', actor: '000000010')

      described_class.perform_now(day)

      expect(AdminNotice.find_by(kind: 'daily_digest').detail(:counts)['requests_made']).to eq(2)
    end

    it 'counts the cascades and reindexes recorded that day' do
      notice_on(day, kind: 'visibility_cascade')
      notice_on(day, kind: 'set_reindex')
      notice_on(day - 1, kind: 'set_reindex')

      described_class.perform_now(day)

      counts = AdminNotice.find_by(kind: 'daily_digest').detail(:counts)
      expect(counts['cascades']).to eq(1)
      expect(counts['reindexes']).to eq(1)
    end

    it 'reads the stuck-deposit counts from the triage builder’s own clauses' do
      described_class.perform_now(day)

      counts = AdminNotice.find_by(kind: 'daily_digest').detail(:counts)
      expect(counts['deposits_unconfirmed']).to eq(3)
      expect(counts['deposits_incomplete']).to eq(3)
      expect(Blacklight.default_index).to have_received(:search)
        .with(hash_including(fq: array_including('in_progress_bsi:true')))
    end

    # A digest that cannot reach Solr still carries everything else.
    it 'writes the digest anyway when the index cannot be reached' do
      allow(Blacklight.default_index).to receive(:search).and_raise(StandardError, 'connection refused')

      expect { described_class.perform_now(day) }.to change(AdminNotice, :count).by(1)
      expect(AdminNotice.find_by(kind: 'daily_digest').detail(:counts)['deposits_unconfirmed']).to be_nil
    end
  end

  describe 'the showcase list' do
    it 'lists the day’s promotions with their community, genre and filename' do
      notice_on(day, kind: 'showcase_promotion', outcome: 'promoted', community_name: 'Marine Science',
                     genre: 'Datasets', work_title: 'reef.csv')
      notice_on(day, kind: 'showcase_promotion', outcome: 'refused', reason: 'no_showcase',
                     genre: 'Theses', work_title: 'slides.pptx')
      notice_on(day - 1, kind: 'showcase_promotion', outcome: 'promoted', work_title: 'old.csv')

      described_class.perform_now(day)

      showcases = AdminNotice.find_by(kind: 'daily_digest').detail(:showcases)
      expect(showcases['promoted']).to eq(1)
      expect(showcases['refused']).to eq(1)
      expect(showcases['entries'].pluck('title')).to contain_exactly('reef.csv', 'slides.pptx')
      expect(showcases['entries'].first['community']).to eq('Marine Science')
      expect(showcases['truncated']).to eq(0)
    end

    it 'caps the list and counts the rest, so the digest stays readable' do
      (described_class::ENTRY_CAP + 4).times do |i|
        notice_on(day, kind: 'showcase_promotion', outcome: 'promoted', work_title: "file#{i}.csv")
      end

      described_class.perform_now(day)

      showcases = AdminNotice.find_by(kind: 'daily_digest').detail(:showcases)
      expect(showcases['entries'].size).to eq(described_class::ENTRY_CAP)
      expect(showcases['truncated']).to eq(4)
      expect(showcases['promoted']).to eq(described_class::ENTRY_CAP + 4)
    end
  end

  describe 'one digest per day' do
    it 'writes nothing the second time and does not raise' do
      described_class.perform_now(day)

      expect { described_class.perform_now(day) }.not_to change(AdminNotice, :count)
      expect(described_class.perform_now(day)).to be_nil
    end

    it 'defaults to yesterday, so the scheduled run sums a whole day' do
      described_class.perform_now

      expect(AdminNotice.find_by(kind: 'daily_digest').occurred_on).to eq(Date.yesterday)
    end
  end
end
