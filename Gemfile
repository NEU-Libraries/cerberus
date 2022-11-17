# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 7.0.1'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'

# Use sqlite3 as the database for Active Record
gem 'sqlite3', '~> 1.4'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 5.6'

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
gem 'attr_json'
gem 'blacklight', git: 'https://github.com/projectblacklight/blacklight.git', ref: '98a071c22cba4654f774a347caaa8d9401c5bc80'
gem 'bootstrap', '< 5.2'
gem 'croutons'
gem 'devise'
gem 'devise-i18n'
gem 'enumerations'
gem 'hamlit'
gem 'mods'
gem 'noid-rails', git: 'https://github.com/dgcliff/noid-rails.git', branch: 'rails-7-trial'
gem 'pg'
gem 'rsolr', '>= 1.0', '< 3'
gem 'sassc-rails', '~> 2.1'
gem 'simple_form'
gem 'valkyrie', git: 'https://github.com/samvera/valkyrie.git'
gem 'valkyrie-shrine'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'rspec'
  gem 'rspec-rails'

  # QA gems
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'simplecov', require: false
  gem 'simplecov_json_formatter', '0.1.3' # Version 0.1.4 seems to break codeclimate
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'database_cleaner'
  gem 'factory_bot_rails'
  gem 'selenium-webdriver'
  gem 'webdrivers'
end
