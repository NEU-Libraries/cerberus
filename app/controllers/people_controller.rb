# frozen_string_literal: true

# People / profile pages — public, read-only discovery surfaces for curated
# Person records (the v2 "Faculty & Staff" identity), rendered as Blacklight
# result sets like any other content type.
#
# Addressed by the Person's NOID (params[:id]); the NUID is read server-side
# only and never appears in a URL or rendered page (NEU IT Security: no NUID
# enumeration/scraping surface).
#
#   index — a gated Blacklight search over Person docs. Scoped to a community's
#           affiliated People when reached via /communities/:community_id/people
#           (the Faculty & Staff browse); global at /people otherwise.
#   show  — one person's profile: the curated header (display_name / title /
#           bio / orcid) over a gated faceted search of the works they deposited
#           (depositor_ssi:<nuid>, the nuid resolved server-side from the Person).
#
# Inherits CatalogController for the gated search_service. search_action_url is
# overridden so the embedded facet / search-within / pagination links stay on
# the People surface (/people, /communities/:id/people, or /people/:id) rather
# than escaping to the global catalog (CatalogController#index).
class PeopleController < CatalogController
  def index
    filters = ['internal_resource_tesim:Person']
    if params[:community_id].present?
      @community = find_community(params[:community_id])
      filters << %(affiliated_community_ids_ssim:"#{solr_phrase(params[:community_id])}")
    end
    builder = search_service.search_builder.with(search_state).with_filters(*filters)
    @response = Blacklight.default_index.search(builder)
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

  # Keep the embedded search's facet / search-within / pagination links on the
  # People surface instead of routing them to the global catalog.
  def search_action_url(options = {})
    options = options.to_h if options.is_a?(Blacklight::SearchState)
    target = if params[:id].present? # profile show page
               { action: 'show', id: params[:id] }
             elsif params[:community_id].present?  # community Faculty & Staff
               { action: 'index', community_id: params[:community_id] }
             else                                  # global /people
               { action: 'index' }
             end
    url_for(options.reverse_merge(controller: 'people', **target))
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

    # The community whose Faculty & Staff we're scoping to (for the page header).
    # A bad/unknown noid degrades to nil — the affiliation fq simply matches
    # nothing, so the browse renders empty rather than erroring.
    def find_community(noid)
      AtlasRb::Community.find(noid)
    rescue JSON::ParserError, Faraday::Error
      nil
    end

    # Strip the only characters that could break out of a quoted Solr phrase.
    def solr_phrase(value)
      value.to_s.gsub(/["\\]/, '')
    end
end
