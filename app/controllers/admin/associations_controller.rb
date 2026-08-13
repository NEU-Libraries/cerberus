# frozen_string_literal: true

module Admin
  # Associated works surface. Admin-only management of the typed edges between
  # Works — DRS v1's "associated works", a directed claim that one Work is the
  # codebook, figure, transcription, instructional material or supplemental
  # material *for* another. Nothing moves in the containment tree and no
  # permission changes; this is descriptive.
  #
  #   index  → search for the Work to manage
  #   manage → its edges in both directions, plus a search to assert a new one
  #   add    → POST   an edge, then back to manage
  #   remove → DELETE an edge, then back to manage
  #
  # **Admin-only because Atlas is.** The write is gated to admin and the devolved
  # tier there, because the claim renders on the *target's* page too and the
  # asserter often holds no rights over it. That is stricter than an association
  # being descriptive would suggest, and it is why this is a `/admin/*` surface
  # rather than a tab on the Work edit page: a tab would be dead chrome for every
  # depositor and editor who can reach it.
  #
  # The edge is stored once, on the Work that asserts it, and Atlas derives the
  # other direction — so `add` always writes from the managed Work outward. To
  # assert the reverse claim, manage the other Work. `remove` takes the holder
  # explicitly and so retracts either direction from one panel, which an admin
  # can do because they hold rights on both ends.
  #
  # Titles come from AtlasRb::Resource.find_many rather than the gated search the
  # public box uses. A management surface must show every edge that exists,
  # including one pointing at a tombstoned Work — which the gated search drops,
  # and which would then be unremovable.
  class AssociationsController < BaseController
    breadcrumb_for 'Associated works', :admin_associations_path

    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    # Atlas's 422 codes on an association write, in the admin's terms. The
    # vocabulary is atlas_rb's; the wording is ours.
    REFUSALS = {
      'invalid_type'        => 'That is not a relationship Atlas recognises.',
      'target_not_found'    => 'No Work with that PID — nothing was linked.',
      'invalid_target_type' => 'An association joins two Works. That PID names something else.',
      'self_association'    => 'A Work cannot be associated with itself.',
      'tombstoned_work'     => 'This Work is withdrawn. Restore it before you associate it.',
      'tombstoned_target'   => 'That Work is withdrawn. Restore it before you associate it.'
    }.freeze

    GENERIC_REFUSAL = 'Atlas refused the change — nothing was written.'

    def index
      @results = ResourceSearch.call(scope: self, query: params[:q], types: %w[Work]) if params[:q].present?
    end

    def manage
      breadcrumb 'Manage', admin_associations_manage_path(work_id: params[:work_id])
      load_work
      return if params[:q].blank?

      # exclude_node_uuid keeps the managed Work out of its own candidate list,
      # pre-empting Atlas's self_association rejection at the point of choice.
      @results = ResourceSearch.call(scope: self, query: params[:q], types: %w[Work],
                                     exclude_node_uuid: @work.resource.valkyrie_id)
    end

    def add
      AtlasRb::Work.associate(params[:work_id], params[:target_id], type: params[:type])
      redirect_to manage_path, notice: 'Association added.'
    rescue AtlasRb::WorkAssociationError => e
      redirect_to manage_path, alert: REFUSALS.fetch(e.code.to_s, GENERIC_REFUSAL)
    rescue Faraday::Error => e
      log_failure('add', e)
      redirect_to manage_path, alert: GENERIC_REFUSAL
    end

    # holder_id, not work_id: the edge lives on whichever Work asserted it, which
    # for an inbound edge is the other one.
    def remove
      AtlasRb::Work.disassociate(params[:holder_id], params[:target_id], type: params[:type])
      redirect_to manage_path, notice: 'Association removed.'
    rescue AtlasRb::WorkAssociationError => e
      redirect_to manage_path, alert: REFUSALS.fetch(e.code.to_s, GENERIC_REFUSAL)
    rescue Faraday::Error => e
      log_failure('remove', e)
      redirect_to manage_path, alert: GENERIC_REFUSAL
    end

    private

      def manage_path
        admin_associations_manage_path(work_id: params[:work_id])
      end

      def load_work
        @work = AtlasRb::Resource.find(params[:work_id])
        raise ResourceNotFound if @work.nil?

        edges = AtlasRb::Work.associations(params[:work_id])
        @outbound = rows_for(edges['outbound'])
        @inbound = rows_for(edges['inbound'])
      end

      # Atlas's `{predicate => [noid]}` map turned into display rows, titles
      # resolved in one batched find_many rather than a find-per-noid fan-out.
      # find_many is unordered and may drop an unresolvable id, so index by noid
      # and fall back to the bare noid when a title is missing.
      def rows_for(edges)
        edges = {} unless edges.is_a?(Hash)
        by_noid = titles_for(edges.values.flatten.map(&:to_s).uniq)
        AtlasRb::Work::ASSOCIATION_TYPES.filter_map do |type|
          noids = Array(edges[type]).map(&:to_s)
          [type, noids.map { |noid| OpenStruct.new(noid: noid, title: by_noid[noid]) }] if noids.any?
        end.to_h
      end

      def titles_for(noids)
        return {} if noids.empty?

        AtlasRb::Resource.find_many(noids)
                         .to_h { |resource| [resource['noid'], resource.title.presence || resource['noid']] }
                         .tap { |titles| noids.each { |noid| titles[noid] ||= noid } }
      end

      def log_failure(verb, error)
        Rails.logger.error("Admin::AssociationsController##{verb}: #{error.class} #{error.message}")
      end
  end
end
