# frozen_string_literal: true

# Generates a representative spread of usage impressions across the objects
# currently in Solr, so the Usage Analytics dashboard (/admin/impressions) is
# non-empty for demos and UAT. Every panel needs real rows to be meaningful:
# the Overview charts, Top files / Top collections, the human/bot segment
# toggle, the date-range picker, and the CSV/xlsx export. Development/staging
# only; invoked at the tail of `reset:data` (and re-runnable via `reset:impressions`).
#
# The seed flows through the same derivation the live capture path uses: raw
# rows land in the hypertable, distinct user-agents are classified via
# UserAgent.record, and the real rollup jobs derive the human-counts layer — so
# the dashboard's human/bot split behaves exactly as it would on real traffic.
class ImpressionSeeder
  # Browser strings (classified human) and crawler strings (classified bot by
  # the "bot" substring rule). The mix gives the segment toggle something to
  # separate; none of the human strings contain a config bot substring.
  HUMAN_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 ' \
    '(KHTML, like Gecko) Version/17.5 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64; rv:127.0) Gecko/20100101 Firefox/127.0',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 ' \
    '(KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1'
  ].freeze

  BOT_AGENTS = [
    'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
    'Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)'
  ].freeze

  DEFAULT_DAYS = 21
  BOT_SHARE    = 0.15
  # Distinct visitor IPs, drawn from RFC 5737 documentation ranges so seed data
  # can never collide with a real client. Kept well above the per-day volume
  # threshold's reach so no synthetic visitor trips the volume filter.
  IP_POOL_SIZE = 40

  def self.call(...)
    new(...).call
  end

  def initialize(days: DEFAULT_DAYS)
    @days = days
  end

  def call
    work_noids = fetch_work_noids
    return 0 if work_noids.empty?

    # Idempotent re-runs: reset already truncates via db:seed:replant, but the
    # standalone task may run against existing data. The rollup jobs re-derive
    # their own windows, and the continuous-aggregate refresh recomputes from raw.
    Impression.delete_all
    register_user_agents
    inserted = insert_impressions(work_noids)
    refresh_rollups
    inserted
  end

  private

    attr_reader :days

    # Leaf Works only — "Top files" resolves to Works, and container counts
    # derive down from leaf Works, so seeding Work impressions lights up every
    # panel without seeding container rows directly.
    def fetch_work_noids
      Blacklight.default_index.search(
        q: '*:*', fq: ['internal_resource_tesim:Work'], rows: 100_000, fl: 'alternate_ids_ssim'
      ).documents.filter_map { |doc| Array(doc['alternate_ids_ssim']).first&.delete_prefix('id-') }
    end

    def register_user_agents
      (HUMAN_AGENTS + BOT_AGENTS).each { |ua| UserAgent.record(ua) }
    end

    def insert_impressions(work_noids)
      rows = []
      work_noids.each_with_index do |noid, index|
        # Popularity decays down the list so Top files has a clear, stable ranking.
        weight = 1.0 - (index.to_f / (work_noids.size + 1))
        days.times do |ago|
          midnight = ago.days.ago.beginning_of_day
          rand(0..(8 * weight).ceil).times { rows << row(noid, 'view', midnight) }
          rand(0..(3 * weight).ceil).times { rows << row(noid, 'download', midnight) }
        end
      end
      rows.each_slice(1_000) { |slice| Impression.insert_all(slice) } # rubocop:disable Rails/SkipsModelValidations
      rows.size
    end

    def row(noid, action, midnight)
      bot = rand < BOT_SHARE
      now = Time.current
      {
        noid:,
        action:,
        session_id: SecureRandom.hex(8),
        ip_address: ip_pool.sample,
        referrer:   'direct',
        user_agent: (bot ? BOT_AGENTS : HUMAN_AGENTS).sample,
        created_at: midnight + rand(0...86_400).seconds,
        updated_at: now
      }
    end

    def ip_pool
      @ip_pool ||= Array.new(IP_POOL_SIZE) { "198.51.100.#{rand(1..254)}" }.uniq
    end

    def refresh_rollups
      RollupImpressionsJob.perform_now
      RollupContainerImpressionsJob.perform_now
      refresh_continuous_aggregate
    end

    # The :all segment reads the continuous aggregate, which TimescaleDB otherwise
    # only catches up on its hourly policy. Force a refresh so seeded history is
    # visible immediately; it cannot run inside a transaction, so it is issued on
    # its own and treated as best-effort (the policy would catch up regardless).
    def refresh_continuous_aggregate
      ActiveRecord::Base.connection.execute(
        "CALL refresh_continuous_aggregate('impression_counts_by_day', NULL, NULL)"
      )
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.warn("ImpressionSeeder: continuous-aggregate refresh skipped (#{e.message})")
    end
end
