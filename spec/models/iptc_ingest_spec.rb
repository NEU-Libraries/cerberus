# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IptcIngest, type: :model do
  it 'inherits from Ingest' do
    expect(described_class.superclass).to eq(Ingest)
  end

  describe 'associations' do
    it 'belongs to a load_report' do
      report = create(:load_report)
      ingest = create(:iptc_ingest, load_report: report)
      expect(ingest.load_report).to eq(report)
    end
  end

  describe 'enum' do
    it 'defines expected status values' do
      expect(described_class.statuses).to eq('pending' => 0, 'processing' => 1, 'completed' => 2, 'failed' => 3)
    end
  end
end
