# frozen_string_literal: true

# What adding a results page of Works to a Set would do: which are already in
# it, directly or through an included collection, which are hidden in it, and
# which are left to add. See docs/sets.md ("Adding a page of results").
class SetPageAddition
  # Blacklight's largest page. A longer list did not come from a results page.
  MAX_WORKS = 100

  attr_reader :noids, :contained, :hidden, :to_add

  def initialize(compilation:, noids:, search_service:)
    @noids = Array(noids).compact_blank.uniq.first(MAX_WORKS)
    # A hidden Work is set aside, not missing: adding it again would not bring
    # it back, so it is counted apart and left for the set's page to put back.
    @hidden = Array(compilation['excluded_works']) & @noids
    candidates = @noids - @hidden
    direct = Array(compilation['included_works'])
    resolved = SetResolver.new(compilation: compilation, search_service: search_service).contained_noids(candidates)
    @contained = candidates.select { |noid| direct.include?(noid) || resolved.include?(noid) }
    @to_add = candidates - @contained
  end
end
