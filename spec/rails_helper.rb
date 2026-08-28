# frozen_string_literal: true

require 'simplecov'

SimpleCov.start 'rails' do
  skip 'spec'
  skip 'vendor'
  skip 'app/channels'
  skip 'lib/cerberus/vocab'
  skip 'app/indexers'
  # The floor is a property of the whole suite, so it can only be judged by a
  # run of the whole suite. Any subset — `rake smoke`, or the handful of files
  # that cover a patch in progress — would fail on coverage alone and say
  # nothing about the code under test. SMOKE lifts the floor; it does not
  # disable the report.
  minimum_coverage 90 unless ENV['SMOKE']
end

# libvips writes glib warnings straight to stderr, outside the Rails logger, and
# ruby-vips cannot forward them to one (its log handler deadlocks on the GIL).
# The specs deliberately feed corrupt images to the probe and derivative paths to
# assert the graceful-degradation branches, so those warnings are expected output
# and only obscure the rspec report. libvips reads this at init and suppresses the
# VIPS log domain when it is set to any value.
ENV['VIPS_WARNING'] ||= '1'

# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires ViewComponent test methods
require 'view_component/test_helpers'
require 'view_component/system_test_helpers'
require 'capybara/rspec'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Rails.root.glob('spec/support/**/*.rb').sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # The preflight and the lock are both taken BEFORE the reset, not after: the
  # reset is the destructive step, so anything that could veto it has to run
  # first. The preflight checks which instance is about to be wiped; the lock
  # stops a second run from wiping the first run's store mid-flight.
  config.before(:suite) do
    SpecPreflight.assert_safe_to_reset!
    ExclusiveRunLock.acquire!
    AtlasRb::Reset.clean
  end

  # Default acting-NUID for tests = admin fixture. Spec setup (let blocks
  # creating Communities / Collections / Works directly via AtlasRb) runs
  # outside a controller context, so the ApplicationController before_action
  # that normally sets Current.nuid doesn't fire. Jobs and other code paths
  # that read Current.nuid pick up this admin default during tests.
  # Controllers under test still override Current.nuid via their before_action
  # based on the signed-in user (or the guest fallback when no user is signed
  # in), so the override-chain mirrors production.
  config.before(:each) { Current.nuid = '000000004' }

  # Live LoC smoke tests are opt-in via RUN_LOC_SMOKE=1; default rspec runs
  # exclude them entirely rather than dumping seven "pending" lines per run.
  # See spec/integration/kataba_loc_regression_spec.rb for the rationale.
  config.filter_run_excluding :loc_smoke unless ENV['RUN_LOC_SMOKE']

  # The Atlas round-trip profile reports numbers rather than asserting anything,
  # so a default run (and CI) skips it. Opt in with RUN_PROFILE=1 or by naming the
  # tag. See spec/integration/atlas_roundtrip_profile_spec.rb.
  config.filter_run_excluding :profile unless ENV['RUN_PROFILE']

  config.include Devise::Test::ControllerHelpers, type: :controller
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [Rails.root.join('spec/fixtures').to_s]

  # Adding config includes for ViewComponent Test Helpers
  config.include ViewComponent::TestHelpers, type: :component
  config.include ViewComponent::SystemTestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
