# frozen_string_literal: true

module Admin
  # Linked members surface. Admin-only management of a Work's *linked*
  # collection placements — the leaves-only DAG overlay (`a_linked_member_of`)
  # that surfaces a Work in additional Collections without moving it or changing
  # its permissions. The Work's structural home (`a_member_of`) is never touched
  # here.
  #
  #   index  → search for the Work to manage
  #   manage → its linked collections, with add (search) / remove affordances
  #   add    → POST   a linked membership, then back to manage
  #   remove → DELETE a linked membership, then back to manage
  #
  # add/remove redirect back to manage, which re-reads the live linked list from
  # Atlas — so the panel always reflects Atlas truth even though atlas_rb's
  # binding swallows a rejected 4xx (see the reparent/linked-member error gap
  # report). The acting admin's NUID flows ambiently (Current.nuid).
  class LinkedMembersController < BaseController
    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    # Step 1 — find the Work.
    def index
      @results = ResourceSearch.call(scope: self, query: params[:q], types: %w[Work]) if params[:q].present?
    end

    # Manage panel — the Work's linked collections + an add-a-collection search.
    def manage
      load_work
      @results = ResourceSearch.call(scope: self, query: params[:q], types: %w[Collection]) if params[:q].present?
    end

    # Add a linked membership (discovery placement only).
    def add
      AtlasRb::Work.add_linked_member(params[:work_id], params[:collection_id])
      redirect_to admin_linked_members_manage_path(work_id: params[:work_id]),
                  notice: 'Collection added. If it does not appear below, the link was rejected ' \
                          '(e.g. the Work is already a structural member, or the target is not a Collection).'
    end

    # Remove a linked membership. Distinct from withdrawing the Work — this only
    # drops a discovery placement; the Work and its home are untouched.
    def remove
      AtlasRb::Work.remove_linked_member(params[:work_id], params[:collection_id])
      redirect_to admin_linked_members_manage_path(work_id: params[:work_id]),
                  notice: 'Removed from that collection.'
    end

    private

      def load_work
        @work = AtlasRb::Resource.find(params[:work_id]) # .resource.title + ancestors
        @home_noid = Array(@work.resource.ancestors).last&.first
        @linked_noids = Array(AtlasRb::Work.linked_members(params[:work_id]))
        @linked = @linked_noids.map { |noid| OpenStruct.new(noid: noid, title: collection_title(noid)) }
        # Collections the Work already sits in (home + linked) can't be added again.
        @placed_noids = (@linked_noids + [@home_noid]).compact.to_set
      end

      def collection_title(noid)
        AtlasRb::Collection.find(noid).title
      rescue StandardError
        noid
      end
  end
end
