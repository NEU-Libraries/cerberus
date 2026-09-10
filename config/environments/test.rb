require "active_support/core_ext/integer/time"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

# One worker's slice of the parallel topology, or the whole thing when running
# unsharded. parallel_tests leaves TEST_ENV_NUMBER empty for the first worker and
# numbers the rest from 2, which is exactly the suffix the compose services and
# the Solr cores carry — so worker 1 keeps talking to the single-instance names
# that a plain `rspec` has always used, and nothing changes for an unsharded run.
#
# Both names have to move together. A run resets whichever Atlas it points at,
# and that reset wipes the Solr core that Atlas writes to; a worker reading a
# core its own Atlas does not own would see another worker's documents and lose
# its own to that worker's reset.
worker = ENV['TEST_ENV_NUMBER'].to_s
suffix = worker.empty? ? '' : "-#{worker}"

ENV['ATLAS_URL'] = "http://atlas-test#{suffix}:3000/"
ENV['SOLR_URL'] ||= "http://solr:8983/solr/blacklight-test#{suffix}"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Turn false under Spring and add config.action_view.cache_template_loading = true.
  config.cache_classes = true

  # Eager loading loads your whole application. When running a single test locally,
  # this probably isn't necessary. It's a good idea to do in a continuous integration
  # system, or in some way before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.

  # Tests assert on the queue with ActiveJob::TestHelper / have_enqueued_job;
  # don't actually run jobs.
  config.active_job.queue_adapter = :test

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true
end
