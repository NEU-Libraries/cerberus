# frozen_string_literal: true

module Admin
  # Linked collection placements for a Work — the discovery overlay
  # (`a_linked_member_of`). See docs/admin.md. Admin-only: this controller keeps
  # BaseController's :admin gate and does not opt into the delegate one.
  #
  # Never touch the structural home (`a_member_of`) here. atlas_rb swallows a
  # rejected 4xx on add and remove, so both redirect to manage, which re-reads
  # the live list from Atlas rather than trusting the call.
  class LinkedMembersController < BaseController
    breadcrumb_for 'Linked members', :admin_linked_members_path

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
      redirect_to admin_linked_members_manage_path(work_id: params[:work_id]),
                  notice: 'Collection added. If it does not appear below, the link was rejected ' \
                          '(e.g. the Work is already a structural member, or the target is not a Collection).'
    end

    def remove
      AtlasRb::Work.remove_linked_member(params[:work_id], params[:collection_id])
      redirect_to admin_linked_members_manage_path(work_id: params[:work_id]),
                  notice: 'Removed from that collection.'
    end

    private

      def load_work
        @work = AtlasRb::Resource.find(params[:work_id]) # .resource.title + ancestors
        raise ResourceNotFound if @work.nil?

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
