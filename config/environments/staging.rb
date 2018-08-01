Cerberus::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb
  config.action_dispatch.x_sendfile_header = "X-Sendfile"

  config.fedora_home = "/opt/fedora/data/datastreamStore/"

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = true

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = false

  # Show full error reports and disable caching
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  config.active_record.auto_explain_threshold_in_seconds = 0.5

  # Do not compress assets
  config.assets.compress = true

  # Serve static assets
  # config.serve_static_assets = true
  # config.static_cache_control = "public, max-age=315360000"

  config.cache_store = :redis_store, 'redis://localhost:6379/0/cache', { expires_in: 12.hours }

  # Expands the lines which load the assets
  config.assets.debug = false

  # Tell Mailer to use localhost:3000 as the default host
  config.action_mailer.default_url_options = { :host => "cerberus.library.northeastern.edu" }
  Rails.application.routes.default_url_options[:host] = "cerberus.library.northeastern.edu"

  # Mailer configuration
  ActionMailer::Base.smtp_settings = {
    address: ENV["MAILER_ADDRESS"],
    port: ENV["MAILER_PORT"],
    domain: ENV["MAILER_DOMAIN"],
    user_name: ENV["MAILER_USERNAME"],
    password: ENV["MAILER_PASSWORD"],
    authentication: ENV["MAILER_AUTHENTICATION"],
    enable_starttls_auto: true
  }

  config.lograge.enabled = false
  config.log_level = :debug

  # config.action_mailer.delivery_method = :sendmail
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  config.middleware.use ExceptionNotification::Rack,
    :email => {
      :email_prefix => "[DRS Staging] ",
      :sender_address => %{"notifier" <notifier@repository.library.northeastern.edu>},
      :exception_recipients => ["dgcliff@northeastern.edu"],
      :email_format => :html
    }


end
