# frozen_string_literal: true

module Admin
  # Curatorial Person registry (admin-only, via Admin::BaseController). Librarians
  # create Person records by NUID, edit the authoritative display_name / title /
  # bio / orcid, and manage community affiliations — the edges that drive the
  # Faculty & Staff browse. All persistence goes through atlas_rb; the acting
  # principal is the signed-in admin (Current.nuid). The NUID is staff-facing
  # (shown here, on an admin-gated surface) but never enters a URL — Persons are
  # addressed by NOID, matching the public People pages.
  #
  # Blacklight::Configurable + the copied Catalog config let ResourceSearch run
  # the community picker on the edit page (same path the linked-members finder
  # uses).
  class PeopleController < BaseController
    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    before_action :set_person, only: %i[edit update add_affiliation remove_affiliation]

    def index
      @people = AtlasRb::Person.list(nuid: Current.nuid)
    end

    def new; end

    def edit
      load_affiliations
      @results = community_search if params[:q].present?
    end

    def create
      person = AtlasRb::Person.create(**create_params, on_behalf_of: Current.nuid)
      # The Person resource is addressed by its NOID, which atlas_rb returns in `id`.
      redirect_to edit_admin_person_path(person['id']),
                  notice: "Person '#{person['display_name']}' created. Add community affiliations below."
    rescue Faraday::Error, JSON::ParserError, ArgumentError => e
      flash.now[:alert] = "Couldn't create that person: #{e.message}"
      render :new, status: :unprocessable_content
    end

    def update
      AtlasRb::Person.update(@noid, **update_params, nuid: Current.nuid)
      redirect_to edit_admin_person_path(@noid), notice: 'Person details saved.'
    rescue Faraday::Error, JSON::ParserError => e
      @person = AtlasRb::Person.find(@noid, nuid: Current.nuid)
      load_affiliations
      flash.now[:alert] = "Couldn't save those details: #{e.message}"
      render :edit, status: :unprocessable_content
    end

    def add_affiliation
      AtlasRb::Person.add_affiliation(@noid, params[:community_id], nuid: Current.nuid)
      redirect_to edit_admin_person_path(@noid), notice: 'Affiliation added.'
    end

    def remove_affiliation
      AtlasRb::Person.remove_affiliation(@noid, params[:community_id], nuid: Current.nuid)
      redirect_to edit_admin_person_path(@noid), notice: 'Affiliation removed.'
    end

    private

      def set_person
        @noid = params[:noid]
        @person = AtlasRb::Person.find(@noid, nuid: Current.nuid)
      rescue JSON::ParserError
        render template: 'errors/not_found', status: :not_found, locals: { obj_type: 'person' }
      end

      # Resolve each affiliated community NOID to a {noid, title} for display. A
      # stale/unreadable id degrades to its NOID rather than breaking the page.
      def load_affiliations
        @affiliations = Array(@person['affiliated_community_ids']).map do |noid|
          { noid: noid, title: community_title(noid) }
        end
      end

      def community_title(noid)
        AtlasRb::Community.find(noid, nuid: Current.nuid)&.title.presence || noid
      rescue Faraday::Error, JSON::ParserError
        noid
      end

      # Community picker for the affiliation finder — the same gated Solr search
      # the linked-members admin uses, scoped to Communities.
      def community_search
        ResourceSearch.call(scope: self, query: params[:q], types: %w[Community])
      end

      def create_params
        params.require(:person).permit(:nuid, :display_name, :title, :bio, :orcid).to_h.symbolize_keys
      end

      def update_params
        params.require(:person).permit(:display_name, :title, :bio, :orcid).to_h.symbolize_keys
      end
  end
end
