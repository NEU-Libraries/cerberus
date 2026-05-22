require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

if defined?(Rails::Server) && Rails.env.development?
  require "debug/open_nonstop"
end

module Cerberus
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.iiif_host = ''
    config.active_job.queue_adapter = :solid_queue

    # Cerberus on-disk data roots. The Dockerfile creates these directories
    # at /home/cerberus/{uploads,images,kataba_cache} by default; ENV overrides
    # let non-container deployments redirect any of them independently.
    config.x.cerberus.data_root         = ENV.fetch('CERBERUS_DATA_ROOT', '/home/cerberus')
    config.x.cerberus.uploads_root      = ENV.fetch('CERBERUS_UPLOADS_ROOT')      { File.join(config.x.cerberus.data_root, 'uploads') }
    config.x.cerberus.derivatives_root  = ENV.fetch('CERBERUS_DERIVATIVES_ROOT')  { File.join(config.x.cerberus.data_root, 'images') }
    config.x.cerberus.schema_cache_root = ENV.fetch('CERBERUS_SCHEMA_CACHE_ROOT') { File.join(config.x.cerberus.data_root, 'kataba_cache') }

    # Acting-NUID sentinel for unauthenticated Cerberus traffic. Atlas's
    # require_auth rejects cerberus-token requests that omit User: NUID; the
    # logged-out path threads this NUID so Atlas resolves to its seeded :guest
    # fixture and applies its read-only policy.
    config.x.cerberus.guest_nuid = ENV.fetch('CERBERUS_GUEST_NUID', '000000001')

    # Route exceptions through ErrorsController so error pages share the
    # application layout (header, footer, search bar). Rails dispatches
    # by status-code path (/404, /500, etc.) when set to self.routes.
    config.exceptions_app = ->(env) { Rails.application.routes.call(env) }

    # config.active_support.to_time_preserves_timezone = :zone
  end
end
