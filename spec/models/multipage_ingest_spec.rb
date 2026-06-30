# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultipageIngest, type: :model do
  it 'inherits from Ingest' do
    expect(described_class.superclass).to eq(Ingest)
  end

  describe 'associations' do
    it 'belongs to a load_report' do
      report = create(:load_report)
      ingest = create(:multipage_ingest, load_report: report)
      expect(ingest.load_report).to eq(report)
    end
  end

  describe 'enum' do
    it 'defines expected status values' do
      expect(described_class.statuses).to eq(
        'pending' => 0, 'processing' => 1, 'completed' => 2, 'failed' => 3, 'completed_with_warnings' => 4
      )
    end
  end

  describe 'warnings serialization' do
    it 'round-trips an array of strings' do
      ingest = create(:multipage_ingest, warnings: %w[first second])
      expect(ingest.reload.warnings).to eq(%w[first second])
    end

    it 'defaults to an empty array' do
      expect(create(:multipage_ingest).warnings).to eq([])
    end
  end

  describe 'page-order uniqueness per item' do
    it 'rejects two rows with the same sequence within one item' do
      report = create(:load_report)
      create(:multipage_ingest, load_report: report, item_index: 0, sequence: 1)
      expect do
        create(:multipage_ingest, load_report: report, item_index: 0, sequence: 1)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows the same sequence across different items in one report' do
      report = create(:load_report)
      create(:multipage_ingest, load_report: report, item_index: 0, sequence: 1)
      expect do
        create(:multipage_ingest, load_report: report, item_index: 1, sequence: 1)
      end.not_to raise_error
    end

    it 'allows multiple nil sequences (failed / structural rows)' do
      report = create(:load_report)
      create(:multipage_ingest, load_report: report, item_index: nil, sequence: nil)
      expect do
        create(:multipage_ingest, load_report: report, item_index: nil, sequence: nil)
      end.not_to raise_error
    end
  end
end
