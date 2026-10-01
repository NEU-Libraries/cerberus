# frozen_string_literal: true

# Adds and removes a community's people from its Edit page's People tab. The
# write is a Person's affiliation, the same one the admin People registry
# edits from the person's side. Admin-only, because Atlas grants Person
# :update to admins and the system principal only.
class CommunityAffiliationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def create
    AtlasRb::Person.add_affiliation(params[:person_id], params[:id], nuid: Current.nuid)
    redirect_to people_tab, notice: 'Person added to this community.'
  rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
    failed('add', e)
  end

  def destroy
    AtlasRb::Person.remove_affiliation(params[:person_id], params[:id], nuid: Current.nuid)
    redirect_to people_tab, notice: 'Person removed from this community.'
  rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
    failed('remove', e)
  end

  private

    def require_admin
      return if current_user&.admin?

      render template: 'errors/forbidden', status: :forbidden, layout: 'application'
    end

    def people_tab
      edit_community_path(params[:id], tab: 'people')
    end

    def failed(verb, error)
      Rails.logger.error("CommunityAffiliationsController##{verb}: #{error.class} #{error.message}")
      redirect_to people_tab, alert: "Couldn't #{verb} that person. Nothing was changed."
    end
end
