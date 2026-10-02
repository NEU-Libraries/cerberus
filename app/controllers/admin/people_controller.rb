# frozen_string_literal: true

module Admin
  # Curatorial Person registry (admin-only, via Admin::BaseController). Librarians
  # create Person records by NUID, edit the authoritative display_name / bio /
  # orcid, and manage community affiliations — the edges that drive the
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

    breadcrumb_for 'Manage people', :admin_people_path

    before_action :set_person, only: %i[edit update add_affiliation remove_affiliation groups]

    # Asked for explicitly: Atlas's default page is 10, and this index used to
    # take it unasked, so everyone past the tenth person was missing.
    PER_PAGE = 50

    # With q, Atlas matches display name, account email and a NUID prefix, and
    # the pagination block counts the matches rather than the registry.
    def index
      @q = params[:q].to_s.strip.presence
      result = AtlasRb::Person.page(q: @q, page: [params[:page].to_i, 1].max, per_page: PER_PAGE,
                                    nuid: Current.nuid)
      @people = Array(result&.dig('people'))
      @pagination = result&.dig('pagination') || {}
    end

    # A Person's Grouper groups live on its sign-in accounts, one set each, so
    # this reads the accounts. One Atlas read, made only when a row is opened.
    def groups
      @accounts = sign_in_accounts
      @failed = @accounts.nil?
      render layout: false
    end

    def new
      breadcrumb 'New', new_admin_person_path
    end

    def edit
      breadcrumb 'Edit', edit_admin_person_path(@noid)
      load_affiliations
      @accounts = sign_in_accounts
      @results = community_search if params[:q].present?
    end

    def create
      person = AtlasRb::Person.create(**create_params, on_behalf_of: Current.nuid)
      NuidResolver.forget(create_params[:nuid])
      # The Person resource is addressed by its NOID, which atlas_rb returns in `id`.
      redirect_to edit_admin_person_path(person['id']),
                  notice: "Person '#{person['display_name']}' created. Add community affiliations below."
    rescue Faraday::Error, JSON::ParserError, ArgumentError => e
      flash.now[:alert] = "Couldn't create that person: #{e.message}"
      render :new, status: :unprocessable_content
    end

    def update
      AtlasRb::Person.update(@noid, **update_params, nuid: Current.nuid)
      NuidResolver.forget(@person['nuid'])
      redirect_to edit_admin_person_path(@noid), notice: 'Person details saved.'
    rescue Faraday::Error, JSON::ParserError => e
      @person = AtlasRb::Person.find(@noid, nuid: Current.nuid)
      load_affiliations
      @accounts = sign_in_accounts
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

      # The person's sign-in accounts, each with its own name and group set. A
      # Person made before its first sign-in has none. Nil means the read
      # failed, which the views say rather than showing an empty list.
      def sign_in_accounts
        nuid = @person['nuid']
        return [] if nuid.blank?

        Array(AtlasRb::User.accounts(nuid, nuid: Current.nuid)&.dig('accounts'))
      rescue AtlasRb::ResourceError, Faraday::Error, JSON::ParserError => e
        Rails.logger.warn("Admin people accounts read failed for #{@noid}: #{e.class}: #{e.message}")
        nil
      end

      # Resolve each affiliated community NOID to a {noid, title} for display. A
      # stale/unreadable id degrades to its NOID rather than breaking the page.
      def load_affiliations
        noids = Array(@person['affiliated_community_ids'])
        titles = noids.empty? ? {} : community_titles(noids)
        @affiliations = noids.map { |noid| { noid: noid, title: titles[noid].presence || noid } }
      end

      # Every affiliated community's title in one batched find_many rather than
      # a find-per-noid fan-out. find_many is unordered and drops an
      # unresolvable id, so index by noid and let the caller re-impose the
      # person's own order.
      def community_titles(noids)
        AtlasRb::Resource.find_many(noids, nuid: Current.nuid).to_h { |node| [node['noid'], node['title']] }
      rescue Faraday::Error, JSON::ParserError
        {}
      end

      # Community picker for the affiliation finder — the same gated Solr search
      # the linked-members admin uses, scoped to Communities.
      def community_search
        ResourceSearch.call(scope: self, query: params[:q], types: %w[Community])
      end

      # Each permitted key is splatted into an atlas_rb keyword signature, so the
      # list is a contract with the gem, not just a mass-assignment filter: a key
      # the binding does not declare raises ArgumentError rather than being
      # ignored.
      def create_params
        params.require(:person).permit(:nuid, :display_name, :bio, :orcid).to_h.symbolize_keys
      end

      def update_params
        params.require(:person).permit(:display_name, :bio, :orcid).to_h.symbolize_keys
      end
  end
end
