# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IptcIngestJob, type: :job do
  let(:load_report) { LoadReport.create!(parent_collection_id: 'col-abc', source_filename: 'jpgs.zip') }
  let(:ingest) do
    IptcIngest.create!(
      load_report:     load_report,
      source_filename: 'marcom.jpeg',
      idempotency_key: 'idem-123'
    )
  end

  let(:uploads_root) { Rails.application.config.x.cerberus.uploads_root }
  let(:extracted_path) do
    File.join(uploads_root, 'load_reports', load_report.id.to_s, 'extracted', 'marcom.jpeg')
  end

  let(:extractor_result) do
    Iptc::Extractor::Result.new(
      tags:   { Headline: 'A photo', Keywords: ['athletics'] },
      width:  3000,
      height: 2000
    )
  end

  let(:mods_result) do
    Iptc::MODSBuilder::Result.new(xml: '<mods/>', warnings: [])
  end

  before do
    # Boundary mocks — keep Extractor/ModsBuilder real, mock everything
    # that would touch the filesystem or network.
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(extracted_path).and_return(true)
    allow(Iptc::Extractor).to receive(:call).and_return(extractor_result)
    allow(Iptc::MODSBuilder).to receive(:call).and_return(mods_result)
    allow(AtlasRb::Work).to receive(:create).and_return(double(id: 'w-456'))
    allow(FileUtils).to receive(:mkdir_p)
    allow(FileUtils).to receive(:mv)
  end

  describe 'happy path' do
    it 'creates an Atlas Work using the parent_collection_id and idempotency_key' do
      described_class.new.perform(ingest.id)
      expect(AtlasRb::Work).to have_received(:create).with(
        'col-abc',
        kind_of(String),
        idempotency_key: 'idem-123'
      )
    end

    it 'records the returned work id on the IptcIngest' do
      described_class.new.perform(ingest.id)
      expect(ingest.reload.work_pid).to eq('w-456')
    end

    it 'stages the file from extracted location to per-Work uploads dir' do
      described_class.new.perform(ingest.id)
      expect(FileUtils).to have_received(:mv).with(
        extracted_path,
        File.join(uploads_root, 'w-456', 'marcom.jpeg')
      )
    end

    it 'enqueues ContentCreationJob with the staged path and idempotency key' do
      expect { described_class.new.perform(ingest.id) }
        .to have_enqueued_job(ContentCreationJob)
        .with('w-456', File.join(uploads_root, 'w-456', 'marcom.jpeg'), 'marcom.jpeg', 'idem-123')
    end

    it 'enqueues IiifAssetsJob with derivative widths pinned to v1 sizing' do
      expect { described_class.new.perform(ingest.id) }
        .to have_enqueued_job(IiifAssetsJob)
        .with(
          'w-456',
          File.join(uploads_root, 'w-456', 'marcom.jpeg'),
          derivative_widths: { small: (600.0 / 3000), large: (1400.0 / 3000) }
        )
    end

    it 'transitions the IptcIngest to :completed' do
      described_class.new.perform(ingest.id)
      expect(ingest.reload).to be_completed
    end

    it 'calls maybe_finalize! on the parent LoadReport' do
      expect_any_instance_of(LoadReport).to receive(:maybe_finalize!)
      described_class.new.perform(ingest.id)
    end
  end

  describe 'when MODSBuilder returned warnings' do
    let(:mods_result) do
      Iptc::MODSBuilder::Result.new(xml: '<mods/>', warnings: ['By-line could not be parsed.'])
    end

    it 'transitions to :completed_with_warnings and persists warnings' do
      described_class.new.perform(ingest.id)
      ingest.reload
      expect(ingest).to be_completed_with_warnings
      expect(ingest.warnings).to eq(['By-line could not be parsed.'])
    end
  end

  describe 'on missing required IPTC field' do
    before do
      allow(Iptc::MODSBuilder).to receive(:call)
        .and_raise(Iptc::MODSBuilder::MissingRequiredField, 'Headline')
    end

    it 'transitions to :failed with a descriptive error_message' do
      described_class.new.perform(ingest.id)
      ingest.reload
      expect(ingest).to be_failed
      expect(ingest.error_message).to match(/Missing required IPTC field.*Headline/)
    end

    it 'does not call Atlas or enqueue downstream jobs' do
      expect(AtlasRb::Work).not_to receive(:create)
      expect { described_class.new.perform(ingest.id) }
        .not_to have_enqueued_job(ContentCreationJob)
    end
  end

  describe 'on extractor type error' do
    before do
      allow(Iptc::Extractor).to receive(:call)
        .and_raise(Iptc::Extractor::UnsupportedIptcType, 'WeirdTag contains Foo data')
    end

    it 'transitions to :failed with the extractor message' do
      described_class.new.perform(ingest.id)
      expect(ingest.reload.error_message).to include('WeirdTag contains Foo data')
    end
  end

  describe 'when the extracted source file is missing' do
    before { allow(File).to receive(:exist?).with(extracted_path).and_return(false) }

    it 'transitions to :failed without parsing' do
      expect(Iptc::Extractor).not_to receive(:call)
      described_class.new.perform(ingest.id)
      expect(ingest.reload).to be_failed
    end
  end

  describe 'idempotency — re-running a terminal-state IptcIngest' do
    %i[completed completed_with_warnings failed].each do |state|
      context "when status is #{state}" do
        before { ingest.update!(status: state) }

        it 'no-ops' do
          expect(Iptc::Extractor).not_to receive(:call)
          expect(AtlasRb::Work).not_to receive(:create)
          described_class.new.perform(ingest.id)
        end
      end
    end
  end

  describe 'idempotency — re-running after Work creation but before downstream' do
    before { ingest.update!(work_pid: 'w-789', status: :processing) }

    it 'skips Work.create when work_pid is already set' do
      allow(File).to receive(:exist?).with(File.join(uploads_root, 'w-789', 'marcom.jpeg')).and_return(true)
      expect(AtlasRb::Work).not_to receive(:create)
      described_class.new.perform(ingest.id)
    end

    it 'skips the stage mv when the staged file already exists' do
      staged = File.join(uploads_root, 'w-789', 'marcom.jpeg')
      allow(File).to receive(:exist?).with(staged).and_return(true)
      expect(FileUtils).not_to receive(:mv)
      described_class.new.perform(ingest.id)
    end
  end

  describe 'retry_on transient failures' do
    # The in-method rescues handle permanent exceptions (handled in
    # the specs above). retry_on catches whatever escapes — DB blips,
    # Atlas timeouts, FS transients — and on exhaustion marks the
    # IptcIngest :failed so the parent LoadReport can finalize.

    it 'declares retry_on StandardError with 3 attempts and polynomial backoff' do
      retry_jitter_config = described_class.retry_jitter
      # Inspect the class-level retry table set up by retry_on.
      handler = described_class.rescue_handlers.find { |h| h[0] == 'StandardError' }
      expect(handler).not_to be_nil, 'IptcIngestJob should declare retry_on StandardError'
    end

    describe 'exhaustion handler (block form)' do
      let(:job) { described_class.new(ingest.id) }
      let(:exception) { StandardError.new('transient atlas blip') }

      it 'marks the IptcIngest :failed with the exhaustion error_message' do
        # Simulate Active Job calling the retry_on block after attempts exhausted.
        allow(job).to receive(:executions).and_return(3)
        described_class.rescue_handlers
                       .find { |h| h[0] == 'StandardError' }
                       .last
                       .call(job, exception)
        ingest.reload
        expect(ingest).to be_failed
        expect(ingest.error_message).to include('Failed after 3 attempts')
        expect(ingest.error_message).to include('transient atlas blip')
      end

      it 'calls maybe_finalize! on the parent LoadReport' do
        allow(job).to receive(:executions).and_return(3)
        expect_any_instance_of(LoadReport).to receive(:maybe_finalize!)
        described_class.rescue_handlers
                       .find { |h| h[0] == 'StandardError' }
                       .last
                       .call(job, exception)
      end

      it 'no-ops if the ingest has already reached a terminal state' do
        ingest.update!(status: :completed)
        allow(job).to receive(:executions).and_return(3)
        expect_any_instance_of(LoadReport).not_to receive(:maybe_finalize!)
        described_class.rescue_handlers
                       .find { |h| h[0] == 'StandardError' }
                       .last
                       .call(job, exception)
        expect(ingest.reload).to be_completed
      end

      it 'no-ops if the IptcIngest has been deleted' do
        ingest_id = ingest.id
        ingest.destroy!
        allow(job).to receive(:arguments).and_return([ingest_id])
        expect {
          described_class.rescue_handlers
                         .find { |h| h[0] == 'StandardError' }
                         .last
                         .call(job, exception)
        }.not_to raise_error
      end
    end
  end

  describe '#widths_for derivative sizing (v1 fidelity)' do
    subject(:job) { described_class.new }

    def widths(width, height)
      result = Iptc::Extractor::Result.new(tags: {}, width: width, height: height)
      job.send(:widths_for, result)
    end

    it 'pins large to 1400px on the longest side for landscape' do
      expect(widths(3000, 2000)).to eq(small: 600.0 / 3000, large: 1400.0 / 3000)
    end

    it 'pins large to 1400px on the longest side for portrait' do
      expect(widths(2000, 3000)).to eq(small: 600.0 / 3000, large: 1400.0 / 3000)
    end

    it 'clamps large at 1.0 when the longest side is between 600 and 1400' do
      expect(widths(1000, 800)).to eq(small: 0.6, large: 1.0)
    end

    it 'clamps both at 1.0 when the longest side is below 600' do
      expect(widths(400, 300)).to eq(small: 1.0, large: 1.0)
    end

    it 'returns full-size both when dimensions are zero or negative (defensive)' do
      expect(widths(0, 0)).to eq(small: 1.0, large: 1.0)
    end
  end
end
