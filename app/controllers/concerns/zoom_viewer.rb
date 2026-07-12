# frozen_string_literal: true

# Deep-zoom viewer gating for a Work's show page. The page-turning viewer mounts
# only for multipage works (two+ positioned page FileSets) whose per-page IIIF
# service the effective user may read; a gated service they can't read falls back
# to the static preview rather than 403-ing every tile. Authorization to the
# gated IIIF host rides in the manifest's service URLs (IiifManifest signs the
# identifier), so the viewer needs no grant cookie.
module ZoomViewer
  extend ActiveSupport::Concern

  private

    # +pages+ lets a caller that already fetched the work's file_sets (e.g. the
    # show path, which reads them alongside mods and assets) hand them in, avoiding
    # a second AtlasRb::Work.file_sets round-trip.
    def prepare_zoom_view(work_id, pages: nil)
      pages ||= AtlasRb::Work.file_sets(work_id, nuid: effective_user&.nuid)
      @multipage = pages.count { |page| page['position'].present? } >= 2
      @can_zoom = @multipage && zoom_service_readable?(pages)
    end

    # The per-page service_file delegate carries the work-level `service:` gate;
    # the viewer renders only if the effective user may read it.
    def zoom_service_readable?(pages)
      service = pages.flat_map { |page| Array(page['assets']) }
                     .find { |asset| asset['use'].to_s == 'service_file' && asset['uri'].present? }
      service.present? && helpers.derivative_readable?(service)
    end
end
