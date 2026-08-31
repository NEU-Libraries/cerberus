require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Staging runs behind a TLS-terminating proxy that forwards plain HTTP to Puma.
  # Without this, Rails sees the request as HTTP: request.base_url is computed as
  # http://…, but the browser sends an https:// Origin header, so the CSRF Origin
  # check rejects every non-GET request with a 422 (uploads, logout, token
  # actions — anything POST/PUT/DELETE). assume_ssl makes Rails treat the request
  # as HTTPS so base_url becomes https:// and the Origin matches; force_ssl then
  # marks cookies Secure and sends HSTS. No redirect loop — assume_ssl already
  # reports https, so force_ssl never has to redirect.
  config.assume_ssl = true
  config.force_ssl = true

  config.iiif_host = 'https://cerberusv2.library.northeastern.edu/cantaloupe'

  # Staging terminates TLS but IIIF derivative URLs minted before the switch
  # carry an http:// scheme baked into Solr. Same-origin Cantaloupe means the
  # browser can transparently upgrade them rather than block them as mixed
  # content. Dev is plain http (no TLS), so this is deliberately staging-only.
  config.content_security_policy do |policy|
    policy.upgrade_insecure_requests true
  end

  # Point Solid Queue at the dedicated `queue` database (see config/database.yml).
  # Without this, Solid Queue falls back to the primary connection, whose schema
  # has no solid_queue_* tables (those live in db/queue_schema.rb).
  config.solid_queue.connects_to = { database: { writing: :queue } }

  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }

  # Staging is deployed from an image and never edited in place, so reloading
  # buys nothing here and costs a great deal. Rails' reload interlock serialises
  # concurrent requests, which defeats ParallelAtlasReads: the four Atlas reads a
  # Work show page issues at once stop overlapping, and the batch costs more than
  # running them one after another. Eager loading also turns a load error into a
  # boot failure rather than a 500 on whichever request first reaches the file.
  config.cache_classes = true
  config.eager_load = true

  # Match production. :debug writes every SQL statement and every partial render
  # to disk, which is a real cost on a box serving requests rather than one
  # developer.
  config.log_level = :info

  # Unlike production, and deliberately. Staging's audience is the team, and a
  # failure there is worth reading in full rather than reducing to a 500 page.
  # The cost is that anyone who can reach the host and trigger an exception sees
  # a backtrace, so staging must not carry data that a backtrace could leak.
  config.consider_all_requests_local = true

  # Nearly free, and it is how page latency gets measured here at all. Know what
  # it cannot see: ActionDispatch::ServerTiming collects only notifications
  # raised on the request thread, so request.atlas_rb excludes the Atlas reads
  # ParallelAtlasReads issues on other threads — often the largest block on the
  # page. An unexplained gap in its accounting is the tell.
  config.server_timing = true

  # Prepend all log lines with the following tags. The request id is what makes
  # a Cerberus log line joinable to the Atlas line it caused, which is the only
  # way to see the shape of a request that fans out across both services.
  config.log_tags = [:request_id]

  # Caching needs two things that do not exist yet: a Redis client in the bundle,
  # and a Redis server reachable at REDIS_URL from the staging stack. Until both
  # land this is :null_store, and MaintenanceMode reads the read-only window from
  # Atlas on every request — one extra Atlas round trip per request, site-wide.
  #
  # Configure it against an unreachable server and you get something worse than
  # no cache: a store passes every "is caching on?" check and then no-ops on each
  # read and write, so caching reads as on while doing nothing. Redis rather than
  # :memory_store because the window must not drift between Swarm replicas.
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Store uploaded files on the local file system (see config/storage.yml for options).

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Log rather than raise. Staging is the last place a deprecation can be caught
  # before it becomes a production failure, and raising turns that warning into
  # an outage on the box the team is trying to test against.
  config.active_support.disallowed_deprecation = :log

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Nothing in the deploy aborts on pending migrations, so this page-load check
  # is staging's only signal that the image shipped a migration nobody ran. It
  # costs one schema check per request and measures at zero.
  config.active_record.migration_error = :page_load

  # Costs nothing at :info, because the backtrace work only runs when the query
  # is actually logged. It earns its place the moment someone raises the level
  # to debug something, which is when query source locations are what they want.
  config.active_record.verbose_query_logs = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true
end
