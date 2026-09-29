# frozen_string_literal: true

module Admin
  # Linked collection placements for a Work — the discovery overlay
  # (`a_linked_member_of`). See docs/admin.md. Admin-only: this controller keeps
  # BaseController's :admin gate and does not opt into the delegate one.
  #
  # Never touch the structural home (`a_member_of`) here. Atlas refuses a link
  # it will not make with a 422, which atlas_rb raises as LinkedMemberError;
  # Authorizable does not catch that class, so both actions rescue it here.
  class LinkedMembersController < BaseController
    breadcrumb_for 'Linked members', :admin_linked_members_path

    # Keyed on Atlas's `error` discriminator; an unknown code shows Atlas's own
    # message instead.
    REFUSALS = {
      'already_structural_member' => 'The work already lives in that collection, so it cannot also be linked there.',
      'invalid_target_type'       => 'Only a collection can be linked to.',
      'tombstoned_target'         => 'That collection is tombstoned, so nothing can be linked into it.',
      'tombstoned_work'           => 'This work is tombstoned, so it cannot be linked anywhere.'
    }.freeze

    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    def index
      @results = ResourceSearch.call(scope: self, query: params[:q], types: %w[Work]) if params[:q].present?
    end

    def manage
      breadcrumb 'Manage', admin_linked_members_manage_path(work_id: params[:work_id])
      load_work
      @results = ResourceSearch.call(scope: self, query: params[:q], types: %w[Collection]) if params[:q].present?
    end

    def add
      AtlasRb::Work.add_linked_member(params[:work_id], params[:collection_id])
      back_to_manage(notice: 'Work is now linked to the selected collection.')
    rescue AtlasRb::LinkedMemberError => e
      back_to_manage(alert: refusal(e))
    end

    def remove
      AtlasRb::Work.remove_linked_member(params[:work_id], params[:collection_id])
      back_to_manage(notice: 'Removed from collection.')
    rescue AtlasRb::LinkedMemberError => e
      back_to_manage(alert: refusal(e))
    end

    private

      def back_to_manage(**flash)
        redirect_to admin_linked_members_manage_path(work_id: params[:work_id]), **flash
      end

      def refusal(error)
        REFUSALS.fetch(error.code.to_s) { "The link was refused: #{error.message}" }
      end

      def load_work
        # Resource.find rather than Work.find: this panel reads the wrapped
        # shape, for the resource's own title and its ancestors.
        @work = require_resource!(AtlasRb::Resource.find(params[:work_id]))

        @home_noid = Array(@work.resource.ancestors).last&.dig('noid')
        @linked_noids = Array(AtlasRb::Work.linked_members(params[:work_id]))
        @linked = linked_collections(@linked_noids)
        @placed_noids = (@linked_noids + [@home_noid]).compact.to_set
      end

      # One batched find_many, not a find-per-noid fan-out. It is unordered and
      # may drop an unresolvable id, so index by noid and keep the given order.
      def linked_collections(noids)
        by_noid = noids.empty? ? {} : AtlasRb::Resource.find_many(noids).index_by { |n| n['noid'] }
        noids.map { |noid| OpenStruct.new(noid: noid, title: by_noid[noid]&.title.presence || noid) }
      end
  end
end
