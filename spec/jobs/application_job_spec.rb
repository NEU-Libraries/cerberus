# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  include ActiveJob::TestHelper

  # A test job that doesn't do anything Atlas-side; it just records
  # `Current.nuid` at perform time so we can assert propagation.
  let(:probe_job_class) do
    stub_const('CurrentNuidProbeJob', Class.new(ApplicationJob) do
      cattr_accessor :observed_nuid

      def perform
        self.class.observed_nuid = Current.nuid
      end
    end)
  end

  before { probe_job_class }

  describe 'Current.nuid propagation' do
    it 'captures Current.nuid at enqueue and restores it at perform' do
      Current.set(nuid: 'enqueue-time-nuid') do
        CurrentNuidProbeJob.perform_later
      end

      # Simulate the worker process: Current has been cleared between
      # enqueue and perform.
      Current.nuid = nil
      perform_enqueued_jobs

      expect(CurrentNuidProbeJob.observed_nuid).to eq('enqueue-time-nuid')
    end

    it 'serializes current_nuid into the job payload' do
      Current.set(nuid: '000000004') do
        job = CurrentNuidProbeJob.new
        # `before_enqueue` runs on serialize → perform_later, not on .new.
        # Mimic the enqueue path by invoking the callback directly so we
        # can assert the serialized shape without going through Solid Queue.
        job.run_callbacks(:enqueue) {}
        expect(job.serialize).to include('current_nuid' => '000000004')
      end
    end

    it 'round-trips the value through deserialize' do
      Current.set(nuid: 'rt-nuid') do
        job = CurrentNuidProbeJob.new
        job.run_callbacks(:enqueue) {}
        payload = job.serialize
        restored = ApplicationJob.deserialize(payload)
        expect(restored.current_nuid).to eq('rt-nuid')
      end
    end

    it 'restores Current.nuid only for the perform window, not beyond' do
      Current.nuid = 'outer-nuid'
      Current.set(nuid: 'enqueue-nuid') do
        CurrentNuidProbeJob.perform_later
      end

      Current.nuid = 'pre-perform-nuid'
      perform_enqueued_jobs

      expect(CurrentNuidProbeJob.observed_nuid).to eq('enqueue-nuid')
      expect(Current.nuid).to eq('pre-perform-nuid') # around_perform restored after block
    end

    it 'preserves an explicitly assigned current_nuid over the ambient value' do
      job = CurrentNuidProbeJob.new
      job.current_nuid = 'explicit-nuid'

      Current.set(nuid: 'ambient-nuid') do
        job.run_callbacks(:enqueue) {}
      end

      expect(job.current_nuid).to eq('explicit-nuid')
    end
  end
end
