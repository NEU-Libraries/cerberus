# frozen_string_literal: true

# A person editing their own Person's display name, bio and ORCID. Who may edit
# is decided here from the Person's NUID, never from the URL; Atlas enforces
# the same rule. See docs/people-and-routing.md.
class PersonProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_own_person

  def edit
    @values = @person
  end

  def update
    AtlasRb::Person.update(@noid, **profile_params, nuid: Current.nuid)
    NuidResolver.forget(@person['nuid'])
    redirect_to person_path(@noid), notice: 'Your details are saved.'
  rescue AtlasRb::ResourceError => e
    raise unless e.status == 422

    @values = profile_params.stringify_keys
    flash.now[:alert] = PersonProfileRefusals.message(e)
    render :edit, status: :unprocessable_content
  end

  private

    def load_own_person
      @noid = params[:id]
      @person = require_resource!(AtlasRb::Person.find(@noid, nuid: Current.nuid))
      raise CanCan::AccessDenied unless own_person?

      breadcrumb 'People', people_path
      breadcrumb @person['display_name'].presence || @noid, person_path(@noid)
      breadcrumb 'Edit details', edit_person_path(@noid)
    end

    def own_person?
      @person['nuid'].present? && @person['nuid'] == effective_user&.nuid
    end

    def profile_params
      params.require(:person).permit(:display_name, :bio, :orcid).to_h.symbolize_keys
    end
end
