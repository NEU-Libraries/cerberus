# frozen_string_literal: true

# Owner-scoped rows for the Add-to-set modal: one Atlas page when no filter
# is active; with a filter, a bounded page-walk matched by title and
# re-paginated in-memory. Atlas's list endpoint has no title filter yet
# (gap report: compilations_list_title_filter.md) — swap the filtered path
# to list(q:) and delete the walk when the param lands.
class SetPicker
  PER_PAGE = 10
  # × 50 per list call = the most sets a title-filter pass will scan.
  SEARCH_PAGE_CAP = 10

  def self.call(query:, page:)
    new(query, page).call
  end

  def initialize(query, page)
    @query = query.to_s.strip
    @page = [page.to_i, 1].max
  end

  # @return [Array(Array<Hash>, Hash)] unwrapped compilation rows + a
  #   pagination hash in Atlas's vocabulary ('page' / 'pages' / 'total').
  def call
    @query.blank? ? plain_page : filtered_page
  end

  private

    def plain_page
      result = AtlasRb::Compilation.list(page: @page, per_page: PER_PAGE)
      [unwrap(result), result['pagination']]
    end

    def filtered_page
      matches = owned_sets.select { |set| set['title'].to_s.downcase.include?(@query.downcase) }
      pages = [(matches.size / PER_PAGE.to_f).ceil, 1].max
      page = [@page, pages].min
      slice = Array(matches.slice((page - 1) * PER_PAGE, PER_PAGE))
      [slice, { 'page' => page, 'pages' => pages, 'total' => matches.size }]
    end

    def owned_sets
      sets = []
      1.upto(SEARCH_PAGE_CAP) do |page|
        result = AtlasRb::Compilation.list(page: page, per_page: 50)
        sets.concat(unwrap(result))
        break if page >= result.dig('pagination', 'pages').to_i
      end
      sets
    end

    # .list entries arrive wrapped: {"compilation" => {...}}.
    def unwrap(result)
      Array(result['compilations']).pluck('compilation')
    end
end
