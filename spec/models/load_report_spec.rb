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

    it 'has many multipage_ingests and destroys them when destroyed' do
      report = create(:load_report)
      page = create(:multipage_ingest, load_report: report)
      expect(report.multipage_ingests).to include(page)
      expect { report.destroy }.to change(MultipageIngest, :count).by(-1)
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
    it 'sums xml, iptc, and multipage ingests' do
      report = create(:load_report)
      create_list(:xml_ingest, 2, load_report: report)
      create_list(:iptc_ingest, 3, load_report: report)
      create(:multipage_ingest, load_report: report)
      expect(report.total_ingests).to eq(6)
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

  describe '#maybe_finalize! inbox notification' do
    let(:loader) { create(:loader) }

    it 'messages the creator when the load reaches a terminal state' do
      report = create(:load_report, loader: loader, creator_nuid: '000000003', status: :processing)
      create(:iptc_ingest, load_report: report, status: :completed)
      create(:iptc_ingest, load_report: report, status: :failed)

      expect { report.maybe_finalize! }.to change(Message, :count).by(1)

      message = Message.last
      expect(message).to be_system
      expect(message.recipient_nuid).to eq('000000003')
      expect(message.subject).to eq('Load "test_archive.zip" failed')
      expect(message.body).to include('1 completed, 0 with warnings, 1 failed.')
      expect(message.body).to include("/loaders/#{loader.slug}/loads/#{report.id}")
    end

    it 'does not finalize or message while rows are still pending' do
      report = create(:load_report, creator_nuid: '000000003', status: :processing)
      create(:iptc_ingest, load_report: report, status: :pending)

      expect { report.maybe_finalize! }.not_to change(Message, :count)
      expect(report.reload).to be_processing
    end

    it 'does not message when the report has no creator (pre-inbox rows)' do
      report = create(:load_report, status: :processing)
      create(:iptc_ingest, load_report: report, status: :completed)

      expect { report.maybe_finalize! }.not_to change(Message, :count)
      expect(report.reload).to be_completed
    end

    it 'does not double-send when a retried row job re-triggers finalization' do
      report = create(:load_report, creator_nuid: '000000003', status: :processing)
      create(:iptc_ingest, load_report: report, status: :completed)

      report.maybe_finalize!
      expect { report.maybe_finalize! }.not_to change(Message, :count)
    end
  end

  describe '#maybe_finalize! work-completion barrier' do
    let(:multipage_loader) { create(:loader, :multipage) }

    it 'enqueues CompleteWorkJob when a multipage report settles completed' do
      report = create(:load_report, loader: multipage_loader, status: :processing)
      create(:multipage_ingest, load_report: report, status: :completed, work_pid: 'neu:w1')

      expect { report.maybe_finalize! }.to have_enqueued_job(CompleteWorkJob).with(report.id)
    end

    it 'enqueues CompleteWorkJob when the report settles completed_with_warnings' do
      report = create(:load_report, loader: multipage_loader, status: :processing)
      create(:multipage_ingest, load_report: report, status: :completed_with_warnings, work_pid: 'neu:w1')

      expect { report.maybe_finalize! }.to have_enqueued_job(CompleteWorkJob)
    end

    it 'never enqueues when the report settles failed' do
      report = create(:load_report, loader: multipage_loader, status: :processing)
      create(:multipage_ingest, load_report: report, status: :completed, work_pid: 'neu:w1', sequence: 1)
      create(:multipage_ingest, load_report: report, status: :failed, work_pid: 'neu:w1', sequence: 2)

      expect { report.maybe_finalize! }.not_to have_enqueued_job(CompleteWorkJob)
    end

    it 'never enqueues for non-multipage loaders' do
      report = create(:load_report, loader: create(:loader, :xml), status: :processing)
      create(:xml_ingest, load_report: report, status: :completed)

      expect { report.maybe_finalize! }.not_to have_enqueued_job(CompleteWorkJob)
    end

    it 'enqueues exactly once across re-converging finalization calls' do
      report = create(:load_report, loader: multipage_loader, status: :processing)
      create(:multipage_ingest, load_report: report, status: :completed, work_pid: 'neu:w1')

      report.maybe_finalize!
      expect { report.maybe_finalize! }.not_to have_enqueued_job(CompleteWorkJob)
    end
  end
end
