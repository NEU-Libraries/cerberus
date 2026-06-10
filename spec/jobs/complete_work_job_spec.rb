# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CompleteWorkJob, type: :job do
  let(:loader) { create(:loader, :multipage) }

  def page_entry(noid, position)
    { 'noid' => noid, 'type' => 'image', 'position' => position, 'assets' => [] }
  end

  describe '#perform' do
    it 'completes the Work when Atlas lists every expected page' do
      report = create(:load_report, loader: loader, status: :completed)
      create(:multipage_ingest, load_report: report, status: :completed, work_pid: 'neu:w1', sequence: 1)
      create(:multipage_ingest, load_report: report, status: :completed, work_pid: 'neu:w1', sequence: 2)

      allow(AtlasRb::Work).to receive(:file_sets).with('neu:w1')
                                                 .and_return([page_entry('fs1', 1), page_entry('fs2', 2)])
      allow(AtlasRb::Work).to receive(:complete)

      described_class.perform_now(report.id)

      expect(AtlasRb::Work).to have_received(:complete).with('neu:w1')
    end

    it 'ignores unpositioned FileSets (e.g. derivative containers) in the count' do
      report = create(:load_report, loader: loader, status: :completed)
      create(:multipage_ingest, load_report: report, status: :completed, work_pid: 'neu:w1', sequence: 1)

      listing = [page_entry('fs1', 1), { 'noid' => 'fs-deriv', 'type' => 'derivative', 'position' => nil }]
      allow(AtlasRb::Work).to receive(:file_sets).and_return(listing)
      allow(AtlasRb::Work).to receive(:complete)

      described_class.perform_now(report.id)

      expect(AtlasRb::Work).to have_received(:complete).with('neu:w1')
    end

    it 'excludes nil-sequence rows (structural failures) from the expected count' do
      report = create(:load_report, loader: loader, status: :completed)
      create(:multipage_ingest, load_report: report, status: :completed, work_pid: 'neu:w1', sequence: 1)
      create(:multipage_ingest, load_report: report, status: :failed, work_pid: nil, sequence: nil)

      allow(AtlasRb::Work).to receive(:file_sets).and_return([page_entry('fs1', 1)])
      allow(AtlasRb::Work).to receive(:complete)

      described_class.perform_now(report.id)

      expect(AtlasRb::Work).to have_received(:complete).with('neu:w1')
    end

    it 'does nothing when the report is not in a completed state' do
      report = create(:load_report, loader: loader, status: :failed)
      create(:multipage_ingest, load_report: report, status: :failed, work_pid: 'neu:w1', sequence: 1)

      allow(AtlasRb::Work).to receive(:complete)
      described_class.perform_now(report.id)

      expect(AtlasRb::Work).not_to have_received(:complete)
    end

    it 'does nothing when no row carries a work_pid' do
      report = create(:load_report, loader: loader, status: :completed)
      create(:multipage_ingest, load_report: report, status: :failed, work_pid: nil, sequence: nil)

      allow(AtlasRb::Work).to receive(:complete)
      described_class.perform_now(report.id)

      expect(AtlasRb::Work).not_to have_received(:complete)
    end

    context 'when Atlas disagrees on the page count' do
      it 'leaves the Work incomplete and messages the creator' do
        report = create(:load_report, loader: loader, status: :completed, creator_nuid: '000000003')
        create(:multipage_ingest, load_report: report, status: :completed, work_pid: 'neu:w1', sequence: 1)
        create(:multipage_ingest, load_report: report, status: :completed, work_pid: 'neu:w1', sequence: 2)

        allow(AtlasRb::Work).to receive(:file_sets).and_return([page_entry('fs1', 1)])
        allow(AtlasRb::Work).to receive(:complete)

        expect { described_class.perform_now(report.id) }.to change(Message, :count).by(1)

        expect(AtlasRb::Work).not_to have_received(:complete)
        message = Message.last
        expect(message.recipient_nuid).to eq('000000003')
        expect(message.subject).to include('needs attention')
        expect(message.body).to include('neu:w1').and include('1 page(s)').and include('2 were expected')
      end

      it 'stays silent (but still refuses to complete) without a creator' do
        report = create(:load_report, loader: loader, status: :completed)
        create(:multipage_ingest, load_report: report, status: :completed, work_pid: 'neu:w1', sequence: 1)
        create(:multipage_ingest, load_report: report, status: :completed, work_pid: 'neu:w1', sequence: 2)

        allow(AtlasRb::Work).to receive(:file_sets).and_return([page_entry('fs1', 1)])
        allow(AtlasRb::Work).to receive(:complete)

        expect { described_class.perform_now(report.id) }.not_to change(Message, :count)
        expect(AtlasRb::Work).not_to have_received(:complete)
      end
    end
  end
end
