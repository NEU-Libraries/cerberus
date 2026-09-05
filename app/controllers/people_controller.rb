# frozen_string_literal: true

# People surfaces: the Person profile and the Faculty & Staff browse, rendered
# as gated Blacklight result sets. See docs/people-and-routing.md.
#
# A Person is addressed by NOID. Their NUID is resolved server-side and must
# never reach a URL or a rendered page — no NUID enumeration surface.
class PeopleController < CatalogController
  include WithoutFacetModal

  # Prepended so it runs before Blacklight memoizes search_state: search_state
  # dups params at construction, so a mutation made in the action body is lost.
  prepend_before_action :scope_to_people, only: :index

  def index
    scope_to_community if params[:community_id].present?
    builder = search_service.search_builder.with(search_state)
    builder = builder.with_filters(@community_filter) if @community_filter
    @response = Blacklight.default_index.search(params: builder)
  end

  def show
    @person = AtlasRb::Person.find(params[:id], nuid: Current.nuid)
    raise ResourceNotFound if @person.nil?

    @display_name = @person['display_name']
    @response = deposited_works(@person['nuid'])
    build_profile_breadcrumbs
  end

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

    def scope_to_people
      current = params[:f].respond_to?(:to_unsafe_h) ? params[:f].to_unsafe_h : (params[:f] || {})
      return if current['type_ssim'].present?

      params[:f] = current.merge('type_ssim' => ['Person'])
    end

    def scope_to_community
      @community = find_community(params[:community_id])
      build_faculty_staff_breadcrumbs(params[:community_id])
      @community_filter = %(affiliated_community_ids_ssim:"#{solr_phrase(params[:community_id])}")
    end

    # `match: :exact`: /communities/:id is a prefix of /communities/:id/people, so
    # inclusive matching would mark the community crumb as the current page.
    # The find inside #breadcrumbs runs first, so a failure leaves the trail
    # empty and the rescue rebuilds it from nothing.
    def build_profile_breadcrumbs
      community_noid = Array(@person['affiliated_community_ids']).first.presence
      if community_noid
        breadcrumbs(community_noid, match: :exact)
        breadcrumb('Faculty & Staff', community_people_path(community_noid))
      else
        breadcrumb('People', people_path)
      end
      breadcrumb(@display_name, person_path(params[:id]))
    rescue Faraday::Error, JSON::ParserError
      breadcrumb('People', people_path)
      breadcrumb(@display_name, person_path(params[:id]))
    end

    # `match: :exact` for the same reason as the profile trail.
    def build_faculty_staff_breadcrumbs(community_noid)
      breadcrumbs(community_noid, match: :exact)
      breadcrumb('Faculty & Staff', community_people_path(community_noid))
    rescue Faraday::Error, JSON::ParserError
      breadcrumb('Faculty & Staff', community_people_path(community_noid))
    end

    # The NUID comes from the Person record, never from the URL.
    def deposited_works(nuid)
      builder = search_service.search_builder
                              .with(search_state)
                              .with_filters(%(depositor_ssi:"#{solr_phrase(nuid)}"),
                                            'internal_resource_tesim:Work')
      Blacklight.default_index.search(params: builder)
    end

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
