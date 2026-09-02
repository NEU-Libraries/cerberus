# frozen_string_literal: true

module Admin
  # Admin-only management of the typed edges between Works. Admin-only because
  # Atlas is: the claim renders on the TARGET's page too, and the asserter often
  # holds no rights there. `add` always writes from the managed Work outward,
  # since the edge is stored on the Work that asserts it. See
  # docs/edit-surfaces.md.
  class AssociationsController < BaseController
    breadcrumb_for 'Associated works', :admin_associations_path

    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    # Atlas's 422 codes on an association write, in the admin's terms. Keyed on
    # the envelope's `error` discriminator, which atlas_rb hands back as a
    # String. An unrecognised or absent code falls through to GENERIC_REFUSAL.
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

      @results = ResourceSearch.call(scope: self, query: params[:q], types: %w[Work],
                                     exclude_node_uuid: @work.resource.valkyrie_id)
    end

    def add
      AtlasRb::Work.associate(params[:work_id], params[:target_id], type: params[:type])
      redirect_to manage_path, notice: 'Association added.'
    rescue AtlasRb::WorkAssociationError => e
      redirect_to manage_path, alert: REFUSALS.fetch(e.code, GENERIC_REFUSAL)
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
      redirect_to manage_path, alert: REFUSALS.fetch(e.code, GENERIC_REFUSAL)
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

      # find_many, never the gated search: a management surface must show every
      # edge, including one to a tombstoned Work that would else be unremovable.
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
