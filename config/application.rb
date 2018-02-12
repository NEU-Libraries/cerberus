require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Cerberus
  class Application < Rails::Application

    config.generators do |g|
      g.test_framework :rspec, :spec => true
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    config.application_name = "Digital Repository Service"

    config.active_job.queue_adapter = :resque

    # if !Rails.env.test? && !(!ENV['TRAVIS'].nil? && ENV['TRAVIS'] == 'true')
    #   config.handles_connection = Mysql2::Client.new(:reconnect => true, :host => Rails.application.secrets.handle_host, :username => Rails.application.secrets.handle_username, :password => Rails.application.secrets.handle_password, :database => Rails.application.secrets.handle_database)
    # else
    #   config.handles_connection = nil
    # end
  end
end
