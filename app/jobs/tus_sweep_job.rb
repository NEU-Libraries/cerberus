# frozen_string_literal: true

# Removes resumable uploads that were started and then abandoned. A finished
# upload leaves the TUS store as soon as its form claims it, so anything still
# there past TusStore::EXPIRY is a tab that closed mid-upload. Scheduled hourly
# in config/recurring.yml.
class TusSweepJob < ApplicationJob
  queue_as :background

  def perform
    TusStore.sweep
  end
end
