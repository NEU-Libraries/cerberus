# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Carries the ambient acting NUID across the enqueue → perform boundary;
  # without it an AtlasRb call from a job goes out with no principal. Note that
  # `before_enqueue` does NOT fire on `perform_now`, so a child job's
  # current_nuid is nil — the fallback to the caller's `Current.nuid` in
  # `around_perform` is what keeps the inherited value. See docs/deposit.md.
  attr_accessor :current_nuid

  before_enqueue { |job| job.current_nuid ||= Current.nuid }

  around_perform do |job, block|
    Current.set(nuid: job.current_nuid || Current.nuid) { block.call }
  end

  def serialize
    super.merge('current_nuid' => current_nuid)
  end

  def deserialize(job_data)
    super
    self.current_nuid = job_data['current_nuid']
  end
end
