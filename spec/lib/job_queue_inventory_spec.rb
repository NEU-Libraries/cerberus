# frozen_string_literal: true

require 'rails_helper'

# The rule this file exists to keep: **config.x.cerberus.job_queues names every
# queue the app can enqueue to.**
#
# `rake maintenance:pause_queues` iterates that list, because SolidQueue's own
# `Queue.all` derives names from DISTINCT queue_name over the jobs table — so an
# idle repository reports no queues and gets nothing paused. Declaring the list
# fixes that and creates a new way to be wrong: a job on a queue nobody declared
# keeps running through a maintenance window.
#
# Read from the source rather than by enqueuing, because SolidQueue's models are
# unusable under RAILS_ENV=test: config.solid_queue.connects_to is set in
# development, staging and production only, so in test the models point at the
# primary database, where the tables do not exist.
RSpec.describe 'Job queue inventory' do
  let(:declared) { Rails.application.config.x.cerberus.job_queues }

  # ActiveJob's own fallback when a job declares nothing.
  let(:rails_default) { 'default' }

  def queues_named_in_jobs
    Rails.root.glob('app/jobs/**/*.rb').flat_map do |path|
      path.read.scan(/^\s*queue_as\s+:(\w+)/).flatten
    end.uniq
  end

  it 'declares every queue a job asks for' do
    undeclared = queues_named_in_jobs - declared

    expect(undeclared).to be_empty,
                          "Job(s) enqueue to #{undeclared.join(', ')}, which " \
                          'config.x.cerberus.job_queues does not name. A maintenance window ' \
                          'would not pause it. Add it there.'
  end

  it 'declares the queue a job with no queue_as lands on' do
    expect(declared).to include(rails_default)
  end

  it 'declares nothing that no job uses' do
    unused = declared - queues_named_in_jobs - [rails_default]

    expect(unused).to be_empty,
                      "config.x.cerberus.job_queues names #{unused.join(', ')}, which no job " \
                      'enqueues to. Either a job was removed, or the name is a typo that would ' \
                      'silently pause nothing.'
  end
end
