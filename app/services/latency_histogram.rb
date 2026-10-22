# frozen_string_literal: true

# A latency histogram kept per minute in Redis, so every Puma worker and every
# Swarm replica adds to the same figures. Percentiles are interpolated from the
# bucket counts, so they are approximate by design. See docs/outages.md.
class LatencyHistogram
  # Upper edges in milliseconds. A call slower than the last lands in `inf`.
  BUCKETS_MS = [5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10_000].freeze

  WINDOW_MINUTES = 60
  RETENTION = 2.hours

  # A Redis that will not answer must not add its connect timeout to every
  # call being timed, so a failure stops writes for this long.
  BACKOFF = 30.seconds

  Summary = Data.define(:calls, :failed, :timeouts, :mean_ms, :p50_ms, :p95_ms, :p99_ms)

  class << self
    def redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379/0'), connect_timeout: 1,
                           read_timeout: 0.2, write_timeout: 0.2, reconnect_attempts: 0)
    end

    def suspended? = @suspended_until && Time.current < @suspended_until

    def suspend! = @suspended_until = Time.current + BACKOFF

    def resume! = @suspended_until = nil
  end

  def initialize(name)
    @name = name
  end

  def record(duration_ms, failed: false, timeout: false)
    return if self.class.suspended?

    key = minute_key(Time.current)
    self.class.redis.pipelined do |pipe|
      pipe.hincrby(key, bucket_for(duration_ms), 1)
      pipe.hincrbyfloat(key, 'sum_ms', duration_ms)
      pipe.hincrby(key, 'failed', 1) if failed
      pipe.hincrby(key, 'timeouts', 1) if timeout
      pipe.expire(key, RETENTION.to_i)
    end
  rescue Redis::BaseError => e
    give_up(e)
  end

  # nil when Redis did not answer, so the page can say so rather than show zeros.
  def summary(minutes: WINDOW_MINUTES)
    totals = Hash.new(0.0)
    window_rows(minutes).each { |row| row.each { |field, value| totals[field] += value.to_f } }
    summarize(totals)
  rescue Redis::BaseError => e
    give_up(e)
    nil
  end

  def keys(minutes: WINDOW_MINUTES)
    now = Time.current
    (0...minutes).map { |ago| minute_key(now - ago.minutes) }
  end

  private

    def window_rows(minutes)
      self.class.redis.pipelined { |pipe| keys(minutes: minutes).each { |key| pipe.hgetall(key) } }
    end

    def summarize(totals)
      counts = bucket_fields.map { |field| totals[field].to_i }
      calls  = counts.sum
      Summary.new(
        calls: calls, failed: totals['failed'].to_i, timeouts: totals['timeouts'].to_i,
        mean_ms: calls.zero? ? nil : (totals['sum_ms'] / calls).round,
        p50_ms: percentile(counts, 0.50), p95_ms: percentile(counts, 0.95), p99_ms: percentile(counts, 0.99)
      )
    end

    # Linear interpolation inside the bucket that holds the rank. The open top
    # bucket has no upper edge, so a rank there reports the last edge.
    def percentile(counts, quantile)
      total = counts.sum
      return nil if total.zero?

      rank = quantile * total
      seen = 0
      counts.each_with_index do |count, index|
        next seen += count if seen + count < rank

        lower = index.zero? ? 0 : BUCKETS_MS[index - 1]
        upper = BUCKETS_MS[index] || BUCKETS_MS.last
        return (lower + ((upper - lower) * (rank - seen) / count)).round
      end
    end

    def bucket_for(duration_ms)
      edge = BUCKETS_MS.find { |limit| duration_ms <= limit }
      edge ? "le_#{edge}" : 'le_inf'
    end

    def bucket_fields = BUCKETS_MS.map { |edge| "le_#{edge}" } + ['le_inf']

    # The environment is in the key because development and the specs share
    # one Redis.
    def minute_key(time) = "cerberus:latency:#{Rails.env}:#{@name}:#{time.utc.strftime('%Y%m%d%H%M')}"

    def give_up(error)
      Rails.logger.warn("[latency] #{@name}: Redis did not answer, pausing writes: #{error.class}: #{error.message}")
      self.class.suspend!
      nil
    end
end
