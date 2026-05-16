# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoadReport, type: :model do
  describe 'associations' do
    it 'has many xml_ingests' do
      report = create(:load_report)
      xml = create(:xml_ingest, load_report: report)
      expect(report.xml_ingests).to include(xml)
    end

    it 'has many iptc_ingests' do
      report = create(:load_report)
      iptc = create(:iptc_ingest, load_report: report)
      expect(report.iptc_ingests).to include(iptc)
    end

    it 'destroys xml_ingests when destroyed' do
      report = create(:load_report)
      create(:xml_ingest, load_report: report)
      expect { report.destroy }.to change(XmlIngest, :count).by(-1)
    end

    it 'destroys iptc_ingests when destroyed' do
      report = create(:load_report)
      create(:iptc_ingest, load_report: report)
      expect { report.destroy }.to change(IptcIngest, :count).by(-1)
    end
  end

  describe 'enum' do
    it 'defines expected status values' do
      expect(described_class.statuses).to eq('pending' => 0, 'processing' => 1, 'completed' => 2, 'failed' => 3)
    end
  end

  describe '#start_load' do
    it 'transitions to processing and sets started_at' do
      report = create(:load_report, status: :pending)
      report.start_load
      expect(report.status).to eq('processing')
      expect(report.started_at).to be_present
    end
  end

  describe '#finish_load' do
    it 'transitions to completed and sets finished_at' do
      report = create(:load_report, status: :processing)
      report.finish_load
      expect(report.status).to eq('completed')
      expect(report.finished_at).to be_present
    end
  end

  describe '#fail_load' do
    it 'transitions to failed and sets finished_at' do
      report = create(:load_report, status: :processing)
      report.fail_load
      expect(report.status).to eq('failed')
      expect(report.finished_at).to be_present
    end
  end

  describe '#total_ingests' do
    it 'sums xml and iptc ingests' do
      report = create(:load_report)
      create_list(:xml_ingest, 2, load_report: report)
      create_list(:iptc_ingest, 3, load_report: report)
      expect(report.total_ingests).to eq(5)
    end
  end

  describe '#completed_ingests' do
    it 'counts completed ingests across both types' do
      report = create(:load_report)
      create(:xml_ingest, load_report: report, status: :completed)
      create(:xml_ingest, load_report: report, status: :pending)
      create(:iptc_ingest, load_report: report, status: :completed)
      expect(report.completed_ingests).to eq(2)
    end
  end

  describe '#failed_ingests' do
    it 'counts failed ingests across both types' do
      report = create(:load_report)
      create(:xml_ingest, load_report: report, status: :failed)
      create(:iptc_ingest, load_report: report, status: :pending)
      create(:iptc_ingest, load_report: report, status: :failed)
      expect(report.failed_ingests).to eq(2)
    end
  end
end
