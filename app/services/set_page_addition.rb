# frozen_string_literal: true

# What adding a results page of Works to a Set would do: which are already in
# it, directly or through an included collection, which are hidden in it, and
# which are left to add. See docs/sets.md ("Adding a page of results").
class SetPageAddition
  # Blacklight's largest page. A longer list did not come from a results page.
  MAX_WORKS = 100

  attr_reader :noids, :contained, :hidden, :to_add

  def initialize(compilation:, noids:, search_service:)
    @compilation = compilation
    @search_service = search_service
    @noids = Array(noids).compact_blank.uniq.first(MAX_WORKS)
    # A hidden Work is set aside, not missing: adding it again would not bring
    # it back, so it is counted apart and left for the set's page to put back.
    @hidden = Array(compilation['excluded_works']) & @noids
    candidates = @noids - @hidden
    direct = Array(compilation['included_works'])
    resolved = resolved_noids(candidates)
    @contained = candidates.select { |noid| direct.include?(noid) || resolved.include?(noid) }
    @to_add = candidates - @contained
  end

  private

    # The candidates the Set's recipe already reaches, through the same gated
    # contents query the Set's page runs.
    def resolved_noids(candidates)
      fqs = SetResolver.new(compilation: @compilation, search_service: @search_service).contents_fqs
      return Set.new if fqs.nil? || candidates.empty?

      terms = candidates.map { |noid| "id-#{noid}" }.join(',')
      builder = @search_service.search_builder.with({}).with_filters(*fqs, "{!terms f=alternate_ids_ssim}#{terms}")
      # to_param reads the noid from alternate_ids_tesim; without it in fl, every
      # document falls back to its uuid and nothing matches.
      builder = builder.merge(rows: candidates.size, fl: 'id,alternate_ids_tesim')
      Blacklight.default_index.search(params: builder).documents.to_set(&:to_param)
    end
end
