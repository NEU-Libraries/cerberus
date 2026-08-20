# frozen_string_literal: true

# The NOIDs of the Works a Set currently denotes, for the bulk actions that
# sweep them.
#
# Atlas resolves the recipe rather than Cerberus doing it, because a job has no
# request and SetResolver needs a request-bound gated search service. The
# endpoint also honours the Set's set-asides (Atlas applies the recipe's
# exclusions server-side) and drops tombstoned Works, so neither has to be
# re-derived here.
#
# **The list is collected before anything mutates it, deliberately.** The
# contents endpoint is gated on read, so a sweep that writes as it pages can
# move a Work out of its own result set mid-walk — strip `public` from page 1
# and every later page shifts up by one, silently skipping Works. Collecting
# first costs one NOID string per Work, which is the cheapest thing in the
# payload; the documents themselves are never held (see the batch-job memory
# budget rule).
class SetWorkEnumerator
  # Atlas caps per_page at 100, so asking for more just gets 100.
  PER_PAGE = 100

  # Bound on one sweep, mirroring SetResolver::MAX_EXPORT_ROWS. A recipe that
  # names several large collections can denote far more Works than anyone means
  # to touch in one click, and the caller reports the truncation rather than
  # running for an hour and leaving the reader to guess.
  MAX_WORKS = 10_000

  Result = Struct.new(:noids, :truncated, keyword_init: true)

  # @param set_noid [String] the Compilation's NOID.
  # @param nuid [String, nil] the acting curator, whose discovery scopes the
  #   walk. A full Atlas admin sees every Work; anyone else sees public Works
  #   plus their own groups' (see the callers' notes on what that means).
  def initialize(set_noid:, nuid: nil)
    @set_noid = set_noid
    @nuid = nuid
  end

  # @return [Result] the NOIDs, and whether MAX_WORKS cut the walk short.
  def call
    noids, truncated = walk
    # De-duplicate before capping, so a Work a recipe reaches twice costs one
    # slot rather than two.
    Result.new(noids: noids.uniq.first(MAX_WORKS), truncated: truncated)
  end

  private

    # @return [Array(Array<String>, Boolean)] the NOIDs gathered, and whether the
    #   cap stopped the walk with more to fetch.
    def walk
      noids = []
      page = 1

      loop do
        response = fetch(page)
        batch = Array(response['contents']).pluck('noid').compact
        break if batch.empty?

        noids.concat(batch)
        return [noids, overflowed?(noids, page, response)] if noids.size >= MAX_WORKS
        break if page >= total_pages(response)

        page += 1
      end

      [noids, false]
    end

    def fetch(page)
      AtlasRb::Compilation.contents(@set_noid, page: page, per_page: PER_PAGE, nuid: @nuid)
    end

    # Landing exactly on the cap still counts as truncated when pages remain.
    # Testing only for overflow would report a clean run and silently leave the
    # rest of a large set untouched, which is the one thing an operator must not
    # have to discover for themselves.
    def overflowed?(noids, page, response)
      noids.uniq.size > MAX_WORKS || page < total_pages(response)
    end

    # Trust the pagination when Atlas sends it, so the walk stops on the last
    # page instead of paying one empty request to discover the end.
    def total_pages(response)
      response.dig('pagination', 'pages').to_i
    end
end
