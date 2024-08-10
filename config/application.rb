require File.expand_path('../boot', __FILE__)

require 'rails/all'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development staging test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module Cerberus
  class Application < Rails::Application

    config.generators do |g|
      g.test_framework :rspec, :spec => true
    end

    config.persistent_hostpath        = "https://repository.library.northeastern.edu/files/"
    config.persistent_collection_path = "https://repository.library.northeastern.edu/collections/"

    config.autoload_paths += Dir[ Rails.root.join('app', 'models', '**/') ]
    config.autoload_paths += %W(#{config.root}/lib/helpers)
    config.autoload_paths += %W(#{config.root}/lib)

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
     config.time_zone = 'Eastern Time (US & Canada)'
     config.active_record.default_timezone = :local

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :en

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = true

    # Enable the asset pipeline
    config.assets.enabled = true
    # Default SASS Configuration, check out https://github.com/rails/sass-rails for details
    # config.assets.compress = Rails.env.production?

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    # Namespace is now neu
    config.id_namespace = 'neu'

    # Set a default root collection.
    config.root_community_id = 'neu:1'

    config.noid_template = '.reeddeeddk'
    config.minter_statefile = '/tmp/minter-state'

    config.fits_path = "/opt/fits-0.6.2/fits.sh"

    config.zipnote_path = "/opt/zip31c/zipnote"

    if !ENV['TRAVIS'].nil? && ENV['TRAVIS'] == 'true'
      config.file_path = "file"
      config.minitool_path = "/usr/bin/exiftool"
    else
      # config.file_path = "/usr/local/bin/file"
      config.file_path = "/usr/bin/file"
      # config.minitool_path = "/opt/exiftool/exiftool"
      config.minitool_path = "/usr/bin/exiftool"
    end

    config.ffmpeg_path = 'ffmpeg'
    config.enable_ffmpeg = false
    config.temp_file_base = nil

    if Rails.env.production? || Rails.env.secondary?
      config.tmp_path = "/mnt/libraries/DRStmp"
    else
      config.tmp_path = "#{Rails.root}/tmp"
    end

    Kataba.configuration.offline_storage = "#{Rails.application.config.tmp_path}/xsd_files"
    Kataba.configuration.mirror_list = File.join(Rails.root, 'config', 'mirror.yml')

    if !Rails.env.test? && !(!ENV['TRAVIS'].nil? && ENV['TRAVIS'] == 'true')
      config.handles_connection = Mysql2::Client.new(:reconnect => true, :host => "#{ENV["HANDLE_HOST"]}", :username => "#{ENV["HANDLE_USERNAME"]}", :password => "#{ENV["HANDLE_PASSWORD"]}", :database => "#{ENV["HANDLE_DATABASE"]}")
    else
      config.handles_connection = nil
    end
  end
end
