# frozen_string_literal: true

# The NOIDs of the Works a Set currently denotes, collected in full before
# anything mutates them: the contents endpoint is gated on read, so a sweep that
# writes as it pages moves Works out of its own result set and silently skips
# them. See docs/sets.md.
class SetWorkEnumerator
  # Atlas caps per_page at 100, so asking for more just gets 100.
  PER_PAGE = 100

  MAX_WORKS = 10_000

  Result = Struct.new(:noids, :truncated, keyword_init: true)

  def initialize(set_noid:, nuid: nil)
    @set_noid = set_noid
    @nuid = nuid
  end

  def call
    noids, truncated = walk
    # De-duplicate before capping, so a Work a recipe reaches twice costs one
    # slot rather than two.
    Result.new(noids: noids.uniq.first(MAX_WORKS), truncated: truncated)
  end

  private

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

    # Landing exactly on the cap still counts as truncated when pages remain:
    # testing only for overflow reports a clean run over an untouched remainder.
    def overflowed?(noids, page, response)
      noids.uniq.size > MAX_WORKS || page < total_pages(response)
    end

    def total_pages(response)
      response.dig('pagination', 'pages').to_i
    end
end
