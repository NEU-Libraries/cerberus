# frozen_string_literal: true

# People / profile pages — public, read-only discovery surfaces for curated
# Person records (the v2 "Faculty & Staff" identity).
#
# Addressed by the Person's NOID (params[:id]); the NUID is read server-side
# only and never appears in a URL or rendered page (NEU IT Security: no NUID
# enumeration/scraping surface).
#
#   index — curated people via AtlasRb::Person.list (no Solr/catalog routing).
#   show  — one person's profile: the curated header (display_name / title /
#           bio / orcid) over a gated faceted search of the works they deposited
#           (depositor_ssi:<nuid>, the nuid resolved server-side from the Person).
#
# Inherits CatalogController for the gated search_service; ShowScopedSearch keeps
# the profile's facet / search / pagination links on /people/:id.
class PeopleController < CatalogController
  include ShowScopedSearch

  PER_PAGE = 50

  def index
    @page = [params.fetch(:page, 1).to_i, 1].max
    @people = AtlasRb::Person.list(page: @page, per_page: PER_PAGE, nuid: Current.nuid)
    # Person.list returns just the page's rows (no total), so paginate by page
    # fullness rather than a count.
    @has_next_page = @people.size == PER_PAGE
  end

  def show
    @person = AtlasRb::Person.find(params[:id], nuid: Current.nuid)
    @display_name = @person['display_name']
    @response = deposited_works(@person['nuid'])
  rescue JSON::ParserError
    # Atlas returns an empty 404 body → JSON.parse raises. A public profile
    # exists only for a curated Person, so an unknown id is a clean 404.
    render template: 'errors/not_found', status: :not_found, locals: { obj_type: 'person' }
  end

  private

    # Gated, faceted, paginated works deposited by this NUID. `.with(search_state)`
    # threads live q / facets / sort / page so the profile is browsable. The NUID
    # comes from the Person (server-side) — never from the URL. Restricted to
    # Works: depositor_ssi is also stamped on Collections/Communities the person
    # *created*, but a profile lists scholarly output, not containers.
    def deposited_works(nuid)
      builder = search_service.search_builder
                              .with(search_state)
                              .with_filters(%(depositor_ssi:"#{solr_phrase(nuid)}"),
                                            'internal_resource_tesim:Work')
      Blacklight.default_index.search(builder)
    end

    # Strip the only characters that could break out of a quoted Solr phrase.
    def solr_phrase(value)
      value.to_s.gsub(/["\\]/, '')
    end
end
