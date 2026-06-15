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

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

# Use Redis adapter to run Action Cable in production
# gem "redis", "~> 4.0"

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
gem 'active_decorator'
# >= 1.3.8 ships the relay-signing transport (ES256 signed assertions that
# replace the cerberus_token relay); the signed-assertion cutover depends on it.
gem 'atlas_rb', '>= 1.3.8'
gem 'attr_json'
gem 'blacklight', '>= 8.0', '< 9.0'
gem 'blacklight-gallery'
gem 'bootstrap'
gem 'bootstrap_form'
gem 'cancancan'
gem 'caxlsx' # xlsx writer — loader manifest fixtures now, spreadsheet export later (roo reads)
gem 'dartsass-rails'
gem 'devise'
gem 'devise-i18n'
gem 'diffy' # line-diff for the MODS version-history page (wraps system diff)
gem 'enumerations'
gem 'haml'
gem 'kataba', '>= 1.0.3'
gem 'libreconv'
gem 'loaf'
gem 'mini_exiftool'
gem 'mission_control-jobs'
gem 'namae'
gem 'neu-mods'
gem 'pg'
gem 'roo'
gem 'rsolr', '>= 1.0', '< 3'
gem 'ruby-filemagic'
gem 'ruby-vips'
gem 'sass-embedded'
gem 'solid_queue'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'faker'
  gem 'fix-db-schema-conflicts'
  gem 'rspec'
  gem 'rspec-rails'

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
