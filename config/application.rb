require_relative 'boot'

# Not `rails/all`. Active Storage's vips shim calls `Vips.block_untrusted(true)`
# at load, which disables libvips' unfuzzed loaders — pdfload among them — and
# MasterJp2 renders PDF cover pages through vips directly. Loading a framework
# nothing here uses would cost that capability for a safety property that only
# matters for untrusted uploads Active Storage would be handling.
#
# Action Text and Action Mailbox come out with it: both depend on Active Storage,
# and neither is used (no rich-text attributes, no ApplicationMailbox). Everything
# else `rails/all` loads is kept, Action Cable included — app/channels still
# defines the default connection and channel.
require 'rails'

%w[
  active_record/railtie
  action_controller/railtie
  action_view/railtie
  action_mailer/railtie
  active_job/railtie
  action_cable/engine
  rails/test_unit/railtie
].each { |railtie| require railtie }

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require 'debug/open_nonstop' if defined?(Rails::Server) && Rails.env.development?

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

    # Cantaloupe as reachable FROM THE APP CONTAINER, for server-side
    # info.json reads (IiifManifest dimensions). The public iiif_host is
    # what browsers (and persisted Delegate URIs) use; in compose the two
    # differ — the container reaches the sibling service by name. Blank
    # means "same as public".
    config.x.cerberus.iiif_internal_host = ENV.fetch('CERBERUS_IIIF_INTERNAL_HOST', nil)

    # Gated-derivative model. MasterJp2 writes both the capped display JP2 and
    # the full-res JP2 to the one derivatives root Cantaloupe reads,
    # distinguished by an `open-`/`gated-` filename prefix; the gated Cantaloupe
    # delegate serves `open-*` freely and requires a signed credential for
    # `gated-*`. iiif_signing_secret is the HMAC secret Cerberus shares with that
    # delegate (signed download URLs + deep-zoom identifier tokens).
    config.x.cerberus.iiif_signing_secret = ENV.fetch('CERBERUS_IIIF_SIGNING_SECRET', nil)

    # Where a Work's minted handle resolves. Atlas stores the bare identifier
    # ("<prefix>/<noid>"), so a resolver base is what turns it into a link.
    # CNRI's global proxy answers only for prefixes in the Global Handle
    # Registry; an unregistered prefix must name its own server, which mounts
    # that same proxy. An empty value reads as unset, because compose passes
    # the variable through whether or not .env defines it.
    config.x.cerberus.handle_resolver_base = ENV.fetch('HANDLE_RESOLVER_BASE', nil).presence ||
                                             'https://hdl.handle.net'

    # Acting-NUID sentinel for unauthenticated Cerberus traffic. The
    # logged-out path threads this NUID as the acting user, so the signed
    # assertion Cerberus mints carries sub = guest_nuid and Atlas resolves to
    # its seeded :guest fixture, applying its read-only policy.
    config.x.cerberus.guest_nuid = ENV.fetch('CERBERUS_GUEST_NUID', '000000001')

    # Impressions (analytics) — bot classification + derived-layer rules.
    # These are read at *derivation* time (never frozen onto a raw row), so
    # editing them reclassifies all history. Ported from v1's deploy-bundled
    # config/locales/bots.en.yml; in v2 they are runtime config (an
    # ops-editable form lands with the Phase 2 derived layer). A user-agent
    # is a bot when its lowercased string contains any of these substrings.
    config.x.cerberus.impression_bots = %w[
      slurp crawl nutch bot lynx spider curl java scrape scrapy
      archive doi ltx71 wget index linkcheck inspectiontool lighthouse
    ]
    # Volume rule + load-balancer/VPN allowlist — defined now, consumed by the
    # Phase 2 derived human-counts layer (not exercised by raw capture).
    config.x.cerberus.impression_volume_threshold = 150
    config.x.cerberus.impression_ip_allowlist     = %w[155.33.16.26]

    # Route exceptions through ErrorsController so error pages share the
    # application layout (header, footer, search bar). Rails dispatches
    # by status-code path (/404, /500, etc.) when set to self.routes.
    config.exceptions_app = ->(env) { Rails.application.routes.call(env) }

    # config.active_support.to_time_preserves_timezone = :zone
  end
end
