# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultipageItemJob, type: :job do
  let(:loader) { create(:loader, :multipage) }
  let(:load_report) do
    LoadReport.create!(loader: loader, parent_collection_id: 'col-abc',
                       source_filename: 'postcards.zip', status: :processing)
  end
  let(:uploads_root) { Rails.application.config.x.cerberus.uploads_root }
  let(:extracted_dir) { File.join(uploads_root, 'load_reports', load_report.id.to_s, 'extracted') }
  let(:mods_path) { File.join(extracted_dir, 'a.mods.xml') }

  # Page rows as MultipageUnzipJob would have created them: grouped by
  # item_index, sequence set, work_pid still nil.
  let!(:page1) do
    MultipageIngest.create!(load_report: load_report, item_index: 0, sequence: 1,
                            source_filename: 'a1.tif', idempotency_key: 'k1')
  end
  let!(:page2) do
    MultipageIngest.create!(load_report: load_report, item_index: 0, sequence: 2,
                            source_filename: 'a2.tif', idempotency_key: 'k2')
  end

  before do
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(mods_path).and_return('<mods:mods/>')
    allow(XmlValidator).to receive(:call).and_return([])
    allow(AtlasRb::Work).to receive(:create).and_return(double(id: 'w-1'))
    allow(MultipageIngestJob).to receive(:perform_later)
  end

  def run
    described_class.new.perform(load_report.id, 0, 'a.mods.xml', work_idempotency_key: 'idem-w')
  end

  describe 'happy path' do
    it 'validates the item MODS and mints one Work with the passed idempotency key' do
      run
      expect(XmlValidator).to have_received(:call).with(xml: '<mods:mods/>')
      expect(AtlasRb::Work).to have_received(:create).with('col-abc', mods_path, idempotency_key: 'idem-w')
    end

    it 'stamps work_pid on the item\'s page rows' do
      run
      expect(page1.reload.work_pid).to eq('w-1')
      expect(page2.reload.work_pid).to eq('w-1')
    end

    it 'enqueues one MultipageIngestJob per page row' do
      run
      expect(MultipageIngestJob).to have_received(:perform_later).with(page1.id)
      expect(MultipageIngestJob).to have_received(:perform_later).with(page2.id)
    end
  end

  describe 'MODS invalid' do
    before { allow(XmlValidator).to receive(:call).and_return(['not schema-valid']) }

    it 'fails the item rows and mints nothing' do
      run
      expect(AtlasRb::Work).not_to have_received(:create)
      expect(page1.reload).to be_failed
      expect(page2.reload).to be_failed
      expect(page1.error_message).to include('Invalid MODS: not schema-valid')
    end

    it 'does not enqueue page jobs' do
      run
      expect(MultipageIngestJob).not_to have_received(:perform_later)
    end
  end

  describe 'guards and retry-safety' do
    it 'does nothing when the report already failed' do
      load_report.update!(status: :failed)
      run
      expect(AtlasRb::Work).not_to have_received(:create)
    end

    it 'is a no-op on a retry after a prior attempt minted and stamped work_pid' do
      load_report.multipage_ingests.update_all(work_pid: 'w-1') # rubocop:disable Rails/SkipsModelValidations
      run
      expect(AtlasRb::Work).not_to have_received(:create)
    end

    it 'is a no-op when a prior attempt already failed the item' do
      load_report.multipage_ingests.update_all(status: MultipageIngest.statuses[:failed]) # rubocop:disable Rails/SkipsModelValidations
      run
      expect(XmlValidator).not_to have_received(:call)
      expect(AtlasRb::Work).not_to have_received(:create)
    end
  end

  describe 'exhausted Atlas retries' do
    it 'declares retry_on Faraday::Error' do
      expect(described_class.rescue_handlers.map(&:first)).to include('Faraday::Error')
    end

    it 'fail_item_rows fails every open row of the item and finalizes the report' do
      described_class.fail_item_rows(load_report, 0, 'Atlas unreachable')
      expect(page1.reload).to be_failed
      expect(page2.reload).to be_failed
      expect(page1.error_message).to eq('Atlas unreachable')
      expect(load_report.reload).to be_failed
    end
  end
end
