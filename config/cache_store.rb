# frozen_string_literal: true

# The cache_store configuration shared by the environments that have a real one.
#
# Deliberately the same shape as Atlas's config/cache_store.rb, down to the
# timeouts and the error handler. Staging exists to tell you what production
# will do, and two apps caching against the same Redis with different failure
# behaviour is a staging environment that has quietly stopped answering that
# question.
#
# What Cerberus caches is small but hot. MaintenanceMode reads the read-only
# window on every request, so without a store that is one extra Atlas round trip
# per request, site-wide. NuidResolver caches resolved display names; it
# deliberately does not cache a miss, so an unresolvable NUID still costs a call
# per render.
#
# Redis rather than :memory_store because the maintenance window must not drift
# between Swarm replicas: an operator who closes the window should not have it
# stay open on whichever replica happens to answer next.
#
# Not autoloaded: config/ is outside the autoload paths, so the environment
# files require_relative this one.
module CerberusCacheStore
  # Rails takes `config.cache_store = :name, options`, which is an array
  # assignment — so returning the pair is the same thing written once.
  def self.redis
    [:redis_cache_store, {
      url:       ENV.fetch('REDIS_URL', 'redis://redis:6379/0'),
      namespace: 'cerberus',
      # A cache outage must not take reads down: on a connection error Rails
      # treats the store as a miss and renders, which is the pre-cache
      # behaviour. It is logged rather than swallowed, because a Redis that is
      # simply absent otherwise looks exactly like a cache that is working.
      error_handler:      lambda { |method:, returning:, exception:|
        Rails.logger.warn("cache #{method} failed: #{exception.class} #{exception.message} -> #{returning.inspect}")
      },
      connect_timeout:    1,
      read_timeout:       0.2,
      write_timeout:      0.2,
      reconnect_attempts: 1
    }]
  end
end
