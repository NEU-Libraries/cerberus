# frozen_string_literal: true

# Loads the community Edit page's People tab: who is affiliated, and the
# person search behind its Add. Admin-only, as the tab is
# (EditTabsHelper#edit_tab_visible?).
module CommunityPeopleTab
  extend ActiveSupport::Concern

  PERSON_RESULTS = 10

  private

    def load_people_tab(community_noid)
      return unless effective_user&.admin?

      @affiliates = CommunityAffiliates.call(community_noid: community_noid)
      @person_q = params[:person_q].to_s.strip.presence
      @person_results = person_search if @person_q
    end

    # Fail-soft: a failed search reads as no matches rather than breaking the
    # whole Edit page.
    def person_search
      Array(AtlasRb::Person.list(q: @person_q, per_page: PERSON_RESULTS, nuid: Current.nuid))
    rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
      Rails.logger.error("CommunityPeopleTab#person_search: #{e.class} #{e.message}")
      []
    end
end
