# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '> 8.0', '< 9.0'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
# gem 'sprockets-rails'

# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'propshaft'

# Use sqlite3 as the database for Active Record
gem 'sqlite3'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma'

# DB-backed session store (ActiveRecord::SessionStore) — lifts the ~4KB cookie
# limit app-wide; required by the download queue's growing session payload.
gem 'activerecord-session_store'

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

# Backs config.cache_store in the environments that have a real one. Rails'
# :redis_cache_store needs this gem specifically: redis-client alone does not
# satisfy the `require "redis"` in ActiveSupport::Cache::RedisCacheStore.
# Version floor matches Atlas, so both apps resolve the same client.
gem 'redis', '>= 4.8'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Sass to process CSS
# gem "sassc-rails"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# NEU Gems
# >= 1.9.3 is a floor, not a preference: it typed the two signals Atlas's
# parent-scoped authorization emits — PermissionsError for an ACL write that
# would make a resource more visible than its container, and ForbiddenError on
# a container-create the caller has no edit rights for. Under an older binding
# both pass through as untranslated bodies, so the write silently no-ops and
# the UI reports success. It also adds `depositor:` to Collection.create /
# Community.create, which reset.rake needs to attribute the institutional tree
# to the anonymous NUID rather than to whoever ran the seed.
# 1.16.0 is a floor, not a preference. It makes every read binding consult the
# HTTP status before parsing, so an Atlas error reaches us as a typed
# AtlasRb::ResourceError instead of a JSON::ParserError, a NoMethodError on an
# error envelope, or — worst — an error body returned as data. Authorizable
# rescues the typed error and no longer rescues JSON::ParserError, so an older
# binding would report every unparseable Atlas response as 404 again. It also
# sets per-connection deadlines, without which a hung Atlas holds a Puma thread
# for minutes.
gem 'atlas_rb', '>= 1.16.0'
gem 'blacklight', '~> 9.0'
# 6.x is the first line that allows Blacklight 9; its gemspec pins the 9.0.0
# betas, which 9.0.0 final satisfies.
gem 'blacklight-gallery', '~> 6.0'
gem 'bootstrap'
gem 'bootstrap_form'
gem 'cancancan'
gem 'caxlsx' # xlsx writer — loader manifest fixtures now, spreadsheet export later (roo reads)
gem 'chartkick' # admin usage-analytics charts (importmap-pinned Chart.js); reads pre-bucketed rollups
gem 'dartsass-rails'
gem 'devise'
gem 'devise-i18n'
gem 'diffy' # line-diff for the MODS version-history page (wraps system diff)
gem 'haml'
# json 3.0 dropped the positional options argument that ActiveSupport::JSON.decode
# still passes, so every decode raises ArgumentError — Solid Queue cannot register
# a process and the schema dumper cannot write a jsonb default. Nothing here needs
# 3.x; lift the pin once Rails passes those options as keywords.
gem 'json', '~> 2.21'
# 1.1.3 is a floor, not a preference: it added the open_timeout / read_timeout
# the initializer sets. Before it, a schema host that went quiet held the
# fetching thread on Net::HTTP's 60s defaults, paid per redirect hop and again
# on the alternate-scheme attempt — minutes, on a librarian's request thread.
# It also wraps a timeout as Kataba::Fetcher::FetchTimeout, which is what lets
# XmlValidator report it rather than 500.
gem 'kataba', '>= 1.1.3'
gem 'libreconv'
gem 'loaf'
gem 'mini_exiftool'
gem 'mission_control-jobs'
gem 'namae'
gem 'neu-mods'
gem 'pg'
# The per-request backstop under the per-client deadlines. `require:` is the
# load-bearing part: the gem's default entry point installs a railtie that
# inserts Rack::Timeout into the stack for EVERY request, which would put a
# wall-clock deadline on the streaming downloads and truncate them. Requiring
# only the base class leaves insertion to us — see
# config/initializers/request_deadline.rb.
gem 'rack-timeout', require: 'rack/timeout/base'
gem 'roo'
gem 'rsolr', '>= 1.0', '< 3'
gem 'ruby-vips'
gem 'sass-embedded'
gem 'solid_queue'
gem 'timescaledb' # hypertable migration helper + schema dumper for the impressions analytics store
gem 'zip_kit' # streaming ZIP for bulk set download (no temp file / no whole-archive buffering)

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'faker'
  gem 'fix-db-schema-conflicts'
  gem 'rspec'
  gem 'rspec-rails'

  # Shards the suite across worker processes. Each worker needs its own Atlas
  # instance, because a run's before(:suite) resets whichever one it points at
  # and would otherwise wipe its neighbours' fixtures mid-run; TEST_ENV_NUMBER
  # is what config/environments/test.rb reads to pick that instance.
  gem 'parallel_tests', require: false

  # QA gems
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'simplecov', require: false
  gem 'simplecov_json_formatter', '0.1.3' # Version 0.1.4 seems to break codeclimate

  # Gem age tool
  gem 'next_rails'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'factory_bot_rails'
  gem 'rails-controller-testing'
  gem 'selenium-webdriver'
  gem 'webdrivers'
end
