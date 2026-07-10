# frozen_string_literal: true

# Deep-zoom viewer gating + grant cookie for a Work's show page. The page-turning
# viewer mounts only for multipage works (two+ positioned page FileSets) whose
# per-page IIIF service the effective user may read; a gated service they can't
# read falls back to the static preview rather than 403-ing every tile. When the
# viewer does mount, the browser gets a short-lived grant cookie for the gated
# IIIF host.
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
      issue_zoom_grant if @can_zoom
    end

    # The per-page service_file delegate carries the work-level `service:` gate;
    # the viewer renders only if the effective user may read it.
    def zoom_service_readable?(pages)
      service = pages.flat_map { |page| Array(page['assets']) }
                     .find { |asset| asset['use'].to_s == 'service_file' && asset['uri'].present? }
      service.present? && helpers.derivative_readable?(service)
    end

    # No-op until enforcement is on (the signing secret set); the cookie domain
    # lets it reach a sibling-subdomain IIIF host (unset = host-only, fine for a
    # same-origin/dev host).
    def issue_zoom_grant
      return if Rails.application.config.x.cerberus.iiif_signing_secret.blank?

      cookies[:iiif_grant] = {
        value:     IiifSigner.grant_cookie,
        domain:    Rails.application.config.x.cerberus.gated_cookie_domain,
        same_site: :lax,
        secure:    request.ssl?,
        httponly:  true,
        expires:   IiifSigner::COOKIE_TTL.from_now
      }
    end
end
