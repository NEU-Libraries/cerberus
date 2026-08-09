# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminNotice, type: :model do
  describe 'validations' do
    it 'rejects an unknown kind' do
      expect(described_class.new(kind: 'gossip', subject: 'Hi')).not_to be_valid
    end

    it 'requires a subject' do
      expect(described_class.new(kind: 'set_reindex')).not_to be_valid
    end
  end

  describe 'occurred_on' do
    it 'defaults to today, so a caller never has to supply it' do
      notice = described_class.create!(kind: 'set_reindex', subject: 'Set reindex finished')
      expect(notice.occurred_on).to eq(Time.zone.today)
    end

    it 'keeps an explicit occurred_on, so a late job is attributed to the day it is about' do
      notice = described_class.create!(kind: 'daily_digest', subject: 'Digest',
                                       occurred_on: Date.new(2026, 1, 1))
      expect(notice.occurred_on).to eq(Date.new(2026, 1, 1))
    end

    it 'stores the payload' do
      notice = described_class.create!(kind: 'visibility_cascade', subject: 'Done',
                                       payload: { narrowed: 3, failures: ['abc123'] })
      expect(notice.reload.payload).to eq('narrowed' => 3, 'failures' => ['abc123'])
    end
  end

  describe '#detail' do
    it 'reads a symbol-written payload key back through its string form' do
      notice = described_class.create!(kind: 'showcase_promotion', subject: 'Promoted',
                                       payload: { genre: 'Datasets' })
      expect(notice.reload.detail(:genre)).to eq('Datasets')
      expect(notice.detail('genre')).to eq('Datasets')
    end
  end

  describe 'one digest per day' do
    it 'refuses a second digest for the same day so a manual re-run cannot double-write' do
      described_class.create!(kind: 'daily_digest', subject: 'Digest', occurred_on: Time.zone.today)
      expect { described_class.create!(kind: 'daily_digest', subject: 'Digest again') }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'does not constrain any other kind to one a day' do
      2.times { described_class.create!(kind: 'set_reindex', subject: 'Set reindex finished') }
      expect(described_class.of_kind('set_reindex').count).to eq(2)
    end
  end

  describe 'scopes' do
    let!(:cascade) { described_class.create!(kind: 'visibility_cascade', subject: 'Cascade') }
    let!(:reindex) do
      described_class.create!(kind: 'set_reindex', subject: 'Reindex', occurred_on: 2.days.ago.to_date)
    end

    it 'filters by a known kind and falls through to everything on an unknown one' do
      expect(described_class.of_kind('visibility_cascade').to_a).to eq([cascade])
      expect(described_class.of_kind('nonsense').count).to eq(2)
    end

    it 'buckets by day' do
      expect(described_class.on_day(2.days.ago.to_date).to_a).to eq([reindex])
    end
  end
end
