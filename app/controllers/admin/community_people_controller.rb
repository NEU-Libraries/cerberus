# frozen_string_literal: true

module Admin
  # A community's people, managed from the admin hub as v1's /admin/communities
  # did: who is affiliated, and Add and Remove. The write is a Person's
  # affiliation, the one the People registry edits from the person's side.
  #
  # Admin-only, through BaseController: Atlas grants Person :update to admins
  # and the system principal alone. It sits apart from the community's Edit
  # page on purpose, since editors who may change a community's details must
  # not be offered its people.
  class CommunityPeopleController < BaseController
    breadcrumb_for 'Communities', :admin_communities_path

    PERSON_RESULTS = 10

    before_action :load_community

    def show
      breadcrumb people_crumb, admin_community_people_path(params[:noid])
      @affiliates = CommunityAffiliates.call(community_noid: params[:noid])
      @q = params[:q].to_s.strip.presence
      @person_results = person_search if @q
    end

    def create
      AtlasRb::Person.add_affiliation(params[:person_id], params[:noid], nuid: Current.nuid)
      redirect_to admin_community_people_path(params[:noid]), notice: 'Person added to this community.'
    rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
      failed('add', e)
    end

    def destroy
      AtlasRb::Person.remove_affiliation(params[:person_id], params[:noid], nuid: Current.nuid)
      redirect_to admin_community_people_path(params[:noid]), notice: 'Person removed from this community.'
    rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
      failed('remove', e)
    end

    private

      # One crumb, so the trail never leaves the admin hub; the header's
      # Community page button is the way out. A title ending in "s" takes the
      # bare apostrophe ("Communications' People").
      def people_crumb
        "#{@title}#{@title.end_with?('s') ? '’' : '’s'} People"
      end

      def load_community
        community = require_resource!(AtlasRb::Community.find(params[:noid]))
        @title = community.title.presence || params[:noid]
      end

      # Fail-soft: a failed search reads as no matches rather than breaking the page.
      def person_search
        Array(AtlasRb::Person.list(q: @q, per_page: PERSON_RESULTS, nuid: Current.nuid))
      rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
        Rails.logger.error("Admin::CommunityPeopleController#person_search: #{e.class} #{e.message}")
        []
      end

      def failed(verb, error)
        Rails.logger.error("Admin::CommunityPeopleController##{verb}: #{error.class} #{error.message}")
        redirect_to admin_community_people_path(params[:noid]),
                    alert: "Couldn't #{verb} that person. Nothing was changed."
      end
  end
end
