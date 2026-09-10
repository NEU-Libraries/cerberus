# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LedgerSeeder do
  subject(:seeder) { described_class.new(days: 7) }

  # The seed reads Solr for the objects to hang rows on, and the digest job it
  # calls reads Solr again for the stuck-deposit backlog. One stub answers both:
  # `documents` for the seed's own lookup, keyed on the resource type in the fq,
  # and `total` for the backlog. The backlog is pinned empty so a day counts as
  # quiet unless this seed put something in it.
  let(:indexed) do
    { 'Work'       => [solr_doc('id-work-a', 'Tidal records'), solr_doc('id-work-b', 'Field notes')],
      'Collection' => [solr_doc('id-coll-a', 'Marine Papers')],
      'Community'  => [solr_doc('id-comm-a', 'Marine Sciences')] }
  end

  before do
    allow(Blacklight.default_index).to receive(:search) do |params|
      type = Array(params[:fq]).first.to_s[/internal_resource_tesim:(\w+)/, 1]
      instance_double(Blacklight::Solr::Response, documents: indexed.fetch(type, []), total: 0)
    end
  end

  describe 'the rows it lays down' do
    before { seeder.call }

    it 'seeds one request of every kind the ledger explains' do
      expect(AdminNotice.requests.pluck(:kind))
        .to contain_exactly('request_withdraw', 'request_move', 'request_restrict', 'request_restrict')
    end

    it 'gives a community restriction the subject type that earns the remedy note' do
      restrictions = AdminNotice.of_kind('request_restrict')
      expect(restrictions.map { |n| n.detail(:subject_type) }).to contain_exactly('Collection', 'Community')
    end

    it 'seeds a clean load and one with warnings, so both statuses render' do
      expect(AdminNotice.of_kind('load_report').map { |n| n.detail(:status) })
        .to contain_exactly('completed', 'completed_with_warnings')
    end

    it 'seeds each repository event kind the activity tab carries' do
      kinds = AdminNotice.activity.pluck(:kind).uniq
      expect(kinds).to include('visibility_cascade', 'set_reindex', 'work_completion_mismatch')
    end

    it 'refuses every fourth promotion, with a reason the ledger can put into words' do
      promotions = AdminNotice.of_kind('showcase_promotion').order(:created_at)
      refused = promotions.select { |n| n.detail(:outcome) == 'refused' }

      expect(promotions).not_to be_empty
      expect(refused).not_to be_empty
      expect(refused.map { |n| n.detail(:reason) }).to all(be_in(described_class::REFUSAL_REASONS))
      expect(promotions - refused).to all(satisfy { |n| n.detail(:reason).nil? })
    end

    it 'titles a promotion with a filename, which is what a deposit is named' do
      titles = AdminNotice.of_kind('showcase_promotion').map { |n| n.detail(:work_title) }
      expect(titles).to all(match(/\.(csv|pdf|pptx|xlsx|tif)\z/))
    end

    it 'attributes every row to one of the fixture users reset.rake creates' do
      actors = AdminNotice.where.not(actor_nuid: nil).distinct.pluck(:actor_nuid)
      expect(actors).to all(be_in(%w[000000002 000000010 000000011 000000012]))
    end

    it 'dates every row inside the requested window' do
      expect(AdminNotice.where(occurred_on: ...8.days.ago.to_date)).not_to exist
    end

    it 'returns the number of rows it wrote' do
      expect(described_class.new(days: 7).call).to eq(AdminNotice.count)
    end
  end

  describe 'the objects it hangs rows on' do
    it 'prefers the objects in Solr, so a row links to something real' do
      seeder.call

      subjects = AdminNotice.where.not(subject_noid: nil).distinct.pluck(:subject_noid)
      expect(subjects).to include('work-a', 'work-b', 'coll-a')
    end

    it 'names the indexed community in the promotion payload' do
      seeder.call

      expect(AdminNotice.of_kind('showcase_promotion').map { |n| n.detail(:community_name) })
        .to all(eq('Marine Sciences'))
    end

    it 'tops up with placeholders when the index is short of works' do
      seeder.call

      # Two indexed works plus two placeholders: always producing rows is the
      # point, and a placeholder is only distinguishable by its seeded noid.
      subjects = AdminNotice.where.not(subject_noid: nil).distinct.pluck(:subject_noid)
      expect(subjects.grep(/\Aseed-/)).not_to be_empty
    end

    it 'still produces a full ledger when Solr has nothing at all' do
      allow(Blacklight.default_index).to receive(:search)
        .and_return(instance_double(Blacklight::Solr::Response, documents: [], total: 0))

      expect(seeder.call).to be_positive
      expect(AdminNotice.of_kind('showcase_promotion').map { |n| n.detail(:community_name) })
        .to all(be_in(described_class::PLACEHOLDER_COMMUNITIES))
    end
  end

  describe 'the digests' do
    before { seeder.call }

    # Asserted as a property, not as a list of dates. Which days carry which
    # rows is a presentation choice the seed is free to change, and this exists
    # to populate the interface rather than to be arithmetically faithful. What
    # has to hold is the rule production runs under: a day with nothing on it
    # earns no digest.
    it 'derives a digest only for a day it put rows on' do
      digests = AdminNotice.digests.pluck(:occurred_on)
      seeded_days = AdminNotice.where.not(kind: AdminNotice::DIGEST).distinct.pluck(:occurred_on)

      expect(digests).not_to be_empty
      expect(digests).to all(be_in(seeded_days))
    end

    it 'back-dates each digest to the morning after its day, so it sorts last' do
      digest = AdminNotice.digests.order(:occurred_on).last

      expect(digest.created_at).to eq(digest.occurred_on.next_day.in_time_zone.change(hour: 5, min: 5))
    end

    it 'summarises the events of its own day and not another' do
      day = Date.current - 6
      digest = AdminNotice.digests.find_by(occurred_on: day)

      expect(digest.detail(:counts)['requests_made']).to eq(AdminNotice.requests.on_day(day).count)
    end
  end

  describe 're-running it' do
    it 'clears the prior rows first, so a standalone run is idempotent' do
      seeder.call
      first = AdminNotice.count

      expect(described_class.new(days: 7).call).to eq(first)
    end
  end

  it 'is callable as a class method, which is how reset.rake invokes it' do
    expect(described_class.call(days: 1)).to be_positive
  end

  def solr_doc(alternate_id, title)
    SolrDocument.new('alternate_ids_ssim' => [alternate_id], 'title_tsim' => [title])
  end
end
