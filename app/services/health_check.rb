# frozen_string_literal: true

# Probes the service behind each capability, for the public /health endpoints
# that Nagios polls and for the admin health page. See docs/outages.md.
class HealthCheck
  Result = Data.define(:capability, :service, :ok, :latency_ms, :detail) do
    def status = ok ? 'ok' : 'unavailable'
  end

  SERVICES = {
    repository: 'Postgres',
    jobs:       'Job queue',
    search:     'Solr',
    records:    'Atlas',
    uploads:    'Storage',
    images:     'Cantaloupe'
  }.freeze

  # Run on the caller's thread, because a probe thread would check out a
  # database connection of its own.
  DATABASE_PROBES = %i[repository jobs].freeze

  # Each anonymous request would otherwise fan out to every service.
  CACHE_TTL = 10.seconds

  # A probe that has not answered by then is reported down, and its thread is
  # left to finish on its own. One atlas_rb read can take over thirty seconds
  # with its retries, which is longer than Nagios waits.
  DEADLINE = 5

  class << self
    def capabilities = SERVICES.keys

    def call(fresh: false)
      hits    = fresh ? {} : capabilities.index_with { |key| cache_read(key) }.compact
      misses  = capabilities - hits.keys
      threads = (misses - DATABASE_PROBES).index_with { |key| spawn(key) }
      probed  = misses.index_with { |key| store(threads.key?(key) ? joined(key, threads[key]) : measure(key)) }
      hits.merge(probed).slice(*capabilities)
    end

    def check(key, fresh: false)
      (cache_read(key) unless fresh) ||
        store(DATABASE_PROBES.include?(key) ? measure(key) : joined(key, spawn(key)))
    end

    private

      def cache_read(key)
        cached = Rails.cache.read(cache_key(key))
        cached && Result.new(**cached)
      end

      def store(result)
        Rails.cache.write(cache_key(result.capability), result.to_h, expires_in: CACHE_TTL)
        result
      end

      def cache_key(key) = ['health_check', key]

      def spawn(key)
        context = Current.attributes
        Thread.new(context.dup) do |attrs|
          Current.attributes = attrs
          measure(key)
        end
      end

      def joined(key, thread)
        thread.join(DEADLINE)&.value || result(key, false, DEADLINE * 1000, "No answer within #{DEADLINE} seconds")
      end

      def measure(key)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        healthy, detail = probe(key)
        result(key, healthy, elapsed_ms(started), detail)
      rescue StandardError => e
        result(key, false, elapsed_ms(started), "#{e.class}: #{e.message}")
      end

      def result(key, healthy, latency_ms, detail)
        Result.new(capability: key, service: SERVICES.fetch(key), ok: healthy, latency_ms: latency_ms, detail: detail)
      end

      def elapsed_ms(started) = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      def probe(key) = send(:"probe_#{key}")

      def probe_repository
        ActiveRecord::Base.connection_pool.with_connection { |connection| connection.select_value('SELECT 1') }
        [true, nil]
      end

      # A reachable queue database with no live worker still processes nothing.
      def probe_jobs
        live = SolidQueue::Process.where(last_heartbeat_at: SolidQueue.process_alive_threshold.ago..).count
        live.positive? ? [true, "#{live} live processes"] : [false, 'No worker has reported in']
      end

      def probe_search
        Blacklight.default_index.connection.get('select', params: { q: '*:*', rows: 0 })
        [true, nil]
      end

      # Atlas has no health endpoint of its own, so this is the cheapest
      # authenticated read. A nil is an Atlas that answered without the endpoint.
      def probe_records
        AtlasRb::Maintenance.read(nuid: Rails.application.config.x.cerberus.guest_nuid)
        [true, nil]
      end

      def probe_uploads
        roots = Rails.application.config.x.cerberus.slice(:uploads_root, :derivatives_root).values
        broken = roots.reject { |root| File.directory?(root) && File.writable?(root) }
        broken.empty? ? [true, nil] : [false, "Not writable: #{broken.join(', ')}"]
      end

      def probe_images
        host = Rails.application.config.x.cerberus.iiif_internal_host.presence ||
               Rails.application.config.iiif_host.presence
        return [true, 'Not configured'] if host.nil?

        response = Faraday.get("#{host}/") do |request|
          request.options.open_timeout = 2
          request.options.timeout      = DEADLINE
        end
        response.success? ? [true, nil] : [false, "HTTP #{response.status}"]
      end
  end
end
