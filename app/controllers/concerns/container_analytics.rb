# frozen_string_literal: true

# Builds the scoped ImpressionsReport for a Collection/Community edit page's
# Analytics tab — shared by CollectionsController and CommunitiesController.
# Visible to anyone who can reach the edit page at all (the same :edit
# ability gate as the Metadata/Permissions tabs — no separate admin check):
# a group editor's own container's traffic isn't privileged information the
# way the repo-wide /admin dashboard's cross-container view is. The shared
# partial (shared/_container_analytics) separately gates the "Open in Usage
# Analytics" drill-down link on admin/admin_delegate, since that link leads
# to the admin-only dashboard and would otherwise 403 for most viewers.
module ContainerAnalytics
  extend ActiveSupport::Concern

  private

    # @param resource [AtlasRb::Collection, AtlasRb::Community] the container
    #   being edited — needs .id (noid), .valkyrie_id (Solr uuid), and .title.
    # @param klass [String] 'Collection' or 'Community'.
    # @return [ImpressionsReport] scoped to this container's subtree, default
    #   range/segment (last 90 days, human) — the edit page shows a fixed
    #   snapshot; the (admin-only) "Open in Usage Analytics" link is where
    #   range/segment/further drill-down live.
    def build_container_analytics(resource, klass)
      scope = ImpressionScope.new(item: { noid: resource.id, uuid: resource.valkyrie_id,
                                           klass:, title: resource.title })
      ImpressionsReport.new(scope:)
    end
end
