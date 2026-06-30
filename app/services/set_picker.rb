# frozen_string_literal: true

# Owner-scoped rows for the Add-to-set modal: one Atlas list page, with the
# optional title typeahead passed through as the server-side `q` filter, so
# pagination always describes the filtered result.
class SetPicker
  PER_PAGE = 10

  def self.call(query:, page:)
    new(query, page).call
  end

  def initialize(query, page)
    @query = query.to_s.strip
    @page = [page.to_i, 1].max
  end

  # @return [Array(Array<Hash>, Hash)] unwrapped compilation rows + a
  #   pagination hash in Atlas's (Pagy) vocabulary ('page' / 'pages' /
  #   'count'). .list entries arrive wrapped: {"compilation" => {...}}.
  def call
    result = AtlasRb::Compilation.list(q: @query.presence, page: @page, per_page: PER_PAGE)
    [Array(result['compilations']).pluck('compilation'), result['pagination']]
  end
end
