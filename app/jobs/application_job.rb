# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Carry the ambient acting NUID across the enqueue → perform boundary.
  #
  # Rails 8.1 has no built-in ActiveJob ↔ ActiveSupport::CurrentAttributes
  # propagation: `Current.nuid` set on the request thread does *not*
  # automatically reach the worker thread that runs the job. Background
  # jobs that call `AtlasRb::*` without an explicit `nuid:` kwarg rely on
  # the configured `default_nuid` resolving to `Current.nuid`; if the
  # value isn't restored at perform, the request goes out with no `User:`
  # header and Atlas's `require_auth` rejects it with 400 — surfacing as
  # an unrelated `NoMethodError` when the gem parses the error envelope
  # and returns `nil`.
  #
  # The fix captures `Current.nuid` at enqueue and re-sets it for the
  # duration of `perform`. Child jobs enqueued mid-perform inherit the
  # value the same way, because their own `before_enqueue` runs while
  # the parent's `around_perform` has Current populated.
  attr_accessor :current_nuid

  before_enqueue { |job| job.current_nuid ||= Current.nuid }

  around_perform do |job, block|
    Current.set(nuid: job.current_nuid) { block.call }
  end

  def serialize
    super.merge('current_nuid' => current_nuid)
  end

  def deserialize(job_data)
    super
    self.current_nuid = job_data['current_nuid']
  end
end
