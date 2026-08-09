# frozen_string_literal: true

# Fills the admin ledger (/admin/ledger) with a representative few days, so both
# tabs and the daily digest mean something for demos and UAT. Without it a fresh
# reset leaves the surface empty — and nobody can evaluate an interface with no
# rows in it. Development/staging only; invoked at the tail of `reset:data` and
# re-runnable via `reset:ledger`.
#
# It prefers the objects actually in Solr, so rows link to something real, and
# tops up with placeholders when the index is short — always producing rows is
# the point. A placeholder's subject link can 404, but a repository with no
# Works has larger problems than this list.
#
# The digests are not written by hand. The seed lays down events and then
# DailyDigestJob derives each day from them, the same way ImpressionSeeder lets
# the real rollup jobs derive the analytics layer — so a day the seed left empty
# correctly gets no digest, exactly as in production.
class LedgerSeeder
  DEFAULT_DAYS = 7

  # Enough of each refusal to show every reason the ledger explains, since those
  # are the rows staff read the showcase list for.
  REFUSAL_REASONS = %w[no_showcase not_personal_root atlas_forbidden].freeze

  PLACEHOLDER_WORKS = [
    'Coastal erosion survey, 2026',
    'Annual technical report',
    'Conference slides, spring symposium',
    'Sediment sample dataset'
  ].freeze

  # Only ever rendered as payload text, never linked, so a placeholder here is
  # indistinguishable from a real community on the page.
  PLACEHOLDER_COMMUNITIES = ['Marine and Environmental Sciences', 'College of Engineering'].freeze

  def self.call(...)
    new(...).call
  end

  def initialize(days: DEFAULT_DAYS)
    @days = days
  end

  def call
    # Idempotent re-runs: reset truncates via db:seed:replant, but the
    # standalone task may run against existing rows.
    AdminNotice.delete_all
    seed_requests
    seed_loads
    seed_repository_events
    seed_promotions
    seed_digests
    AdminNotice.count
  end

  private

    attr_reader :days

    def fetch(type)
      @fetch ||= {}
      @fetch[type] ||= Blacklight.default_index.search(
        q: '*:*', fq: ["internal_resource_tesim:#{type}"], rows: 50,
        fl: 'alternate_ids_ssim,title_tsim'
      ).documents.filter_map do |doc|
        noid = Array(doc['alternate_ids_ssim']).first&.delete_prefix('id-')
        { noid: noid, title: Array(doc['title_tsim']).first.to_s.presence || 'Untitled' } if noid
      end
    end

    def works
      @works ||= begin
        found = fetch('Work')
        shortfall = PLACEHOLDER_WORKS.size - found.size
        found + PLACEHOLDER_WORKS.last([shortfall, 0].max).map { |title| placeholder(title) }
      end
    end

    def container(type, fallback_title)
      fetch(type).first || placeholder(fallback_title)
    end

    def placeholder(title) = { noid: "seed-#{SecureRandom.hex(3)}", title: title }

    # One of each kind, including a community restriction — the row carrying the
    # remedy note, and the only one a delegate is told they cannot act on.
    def seed_requests
      request(works[0], 'request_withdraw', 'Work', 6, 'Superseded by the 2026 edition.')
      request(works[1], 'request_move', 'Work', 4, 'Should sit under Engineering Theses.')
      request(container('Collection', 'Working Papers'), 'request_restrict', 'Collection', 2,
              'Archives staff only, please.')
      request(container('Community', 'College of Engineering'), 'request_restrict', 'Community', 1,
              'Nobody outside the department.')
    end

    def request(object, kind, type, days_ago, note)
      notice(kind: kind, days_ago: days_ago, actor: seed_nuids.sample, noid: object[:noid],
             subject: %(Request to #{kind.delete_prefix('request_')} “#{object[:title]}”),
             payload: { subject_type: type, subject_title: object[:title], note: note })
    end

    def seed_loads
      notice(kind: 'load_report', days_ago: 5, actor: seed_nuids.first,
             subject: 'Load "marine-survey-2026.zip" completed',
             body: '48 completed, 0 with warnings, 0 failed.',
             payload: { status: 'completed', completed: 48, warnings: 0, failed: 0 })
      notice(kind: 'load_report', days_ago: 3, actor: seed_nuids.first,
             subject: 'Load "theses-batch-11.zip" completed with warnings',
             body: '12 completed, 3 with warnings, 1 failed.',
             payload: { status: 'completed_with_warnings', completed: 12, warnings: 3, failed: 1 })
    end

    def seed_repository_events
      notice(kind: 'visibility_cascade', days_ago: 4, actor: seed_nuids.sample,
             subject: 'Visibility change finished', noid: container('Collection', 'Working Papers')[:noid],
             body: '31 items narrowed to match the collection.',
             payload: { narrowed: 31, unchanged: 4, failures: [] })
      notice(kind: 'set_reindex', days_ago: 2, actor: seed_nuids.sample,
             subject: 'Set reindex finished', body: '17 resources reindexed.',
             payload: { count: 17, failures: [] })
      notice(kind: 'work_completion_mismatch', days_ago: 3, actor: seed_nuids.first,
             subject: 'Load "theses-batch-11.zip" needs attention', noid: works[2][:noid],
             body: 'The load finished, but the work lists 11 pages where 12 were expected.',
             payload: { expected: 12, actual: 11 })
    end

    # The list librarians read this tab for: what landed on a public showcase,
    # under which genre, and what was refused without anybody hearing.
    def seed_promotions
      genres = FeaturedContent.genre_labels.first(3)
      communities = fetch('Community').first(2).pluck(:title).presence || PLACEHOLDER_COMMUNITIES

      works.first(9).each_with_index do |work, index|
        promotion(work, communities[index % communities.size], genres[index % genres.size], index)
      end
    end

    def promotion(work, community, genre, index)
      refused = (index % 4).zero?
      notice(kind: 'showcase_promotion', days_ago: (index % days) + 1, actor: seed_nuids.sample,
             subject: refused ? 'Showcase publication refused' : %(Published to the “#{genre}” showcase),
             noid: work[:noid],
             payload: { outcome: refused ? 'refused' : 'promoted', genre: genre, community_name: community,
                        reason: (REFUSAL_REASONS[index % REFUSAL_REASONS.size] if refused),
                        work_title: seed_filename(work, index) })
    end

    # A filename rather than the indexed title, because a deposit is titled with
    # its filename — and that is the signal a librarian scans for a wrong genre.
    def seed_filename(work, index)
      extension = %w[csv pdf pptx xlsx tif][index % 5]
      "#{work[:title].parameterize.presence || 'deposit'}.#{extension}"
    end

    # The real job, one day at a time, so each digest matches what the seeded
    # rows say — and a day with nothing in it correctly gets none.
    #
    # Back-dated to the morning after its day, which is when the schedule writes
    # one. Left at the time of seeding, every digest would sort above the events
    # it summarises instead of closing them off.
    def seed_digests
      days.downto(1) do |ago|
        day = Date.current - ago
        digest = DailyDigestJob.perform_now(day)
        written_at = day.next_day.in_time_zone.change(hour: 5, min: 5)
        digest&.update_columns(created_at: written_at, updated_at: written_at) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    # The seeded staff / depositor identities (see reset.rake's fixture users).
    def seed_nuids
      @seed_nuids ||= %w[000000002 000000010 000000011 000000012]
    end

    # rubocop:disable Metrics/ParameterLists -- all keywords, each naming one
    # independent fact about the row; an options hash would only re-hide them.
    def notice(kind:, days_ago:, subject:, actor: nil, noid: nil, body: nil, payload: {})
      at = days_ago.days.ago
      AdminNotice.create!(kind: kind, subject: subject, body: body, actor_nuid: actor,
                          subject_noid: noid, payload: payload, occurred_on: at.to_date,
                          created_at: at, updated_at: at)
    end
  # rubocop:enable Metrics/ParameterLists
end
