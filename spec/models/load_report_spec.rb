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
      expect(described_class.statuses).to eq(
        'pending' => 0, 'processing' => 1, 'completed' => 2, 'failed' => 3,
        'completed_with_warnings' => 4, 'previewing' => 5
      )
    end
  end

  describe '#in_progress? / #terminal?' do
    it 'treats pending and processing as in progress' do
      %i[pending processing].each do |status|
        report = build(:load_report, status: status)
        expect(report).to be_in_progress
        expect(report).not_to be_terminal
      end
    end

    it 'treats completed, completed_with_warnings, and failed as terminal' do
      %i[completed completed_with_warnings failed].each do |status|
        report = build(:load_report, status: status)
        expect(report).to be_terminal
        expect(report).not_to be_in_progress
      end
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

  describe '#processed_ingests / #progress_percent' do
    it 'counts every terminal per-row state (completed, warnings, failed)' do
      report = create(:load_report)
      create(:iptc_ingest, load_report: report, status: :completed)
      create(:iptc_ingest, load_report: report, status: :completed_with_warnings)
      create(:iptc_ingest, load_report: report, status: :failed)
      create(:iptc_ingest, load_report: report, status: :pending)
      create(:iptc_ingest, load_report: report, status: :processing)
      expect(report.processed_ingests).to eq(3)
    end

    it 'expresses processed/total as a rounded percentage' do
      report = create(:load_report)
      create_list(:iptc_ingest, 3, load_report: report, status: :completed)
      create_list(:iptc_ingest, 5, load_report: report, status: :pending)
      expect(report.progress_percent).to eq(38) # 3/8 = 37.5 → 38
    end

    it 'is 0% when there are no ingests (no divide-by-zero)' do
      expect(create(:load_report).progress_percent).to eq(0)
    end
  end
end
