# frozen_string_literal: true

# The two branches of the weighted deposit fork — workspace vs publish — and
# the shared tail that finalizes a freshly created Work. Pulled out of
# WorksController so the controller stays focused on request wiring; the branch
# helpers lean on the controller's own deposit_attribution / stage_upload /
# enqueue_ingest_jobs and on DepositorContext for the publish target.
module WorkDeposit
  extend ActiveSupport::Concern

  private

    # Deposit into the container the route named. There is only one destination
    # path now: the Work lives where the depositor navigated, and nothing later
    # in the request moves it.
    def create_at_destination(file)
      parent = AtlasRb::Collection.find(@destination_id)
      raise ResourceNotFound if parent.nil?

      @work = AtlasRb::Work.create(parent.id, depositor: deposit_attribution(parent))
      finalize_new_work(file, parent.id)
    end

    # Additionally surface the new Work in a community genre showcase, via a
    # linked-member edge. Promotion is orthogonal to placement: the Work's
    # structural home is wherever it was just deposited and is untouched here.
    # The form only offers this when the destination is the depositor's own
    # personal root (WorksController#publish_offered?), so a promoted Work still
    # sits in their own space — the property the old publish branch got by
    # relocating the Work, now got by restricting where you can promote from.
    #
    # The showcase link is a :system-attributed write (AtlasRb::System::Work),
    # not a call the depositor's own credential could make — Atlas scopes
    # :system's grant to a featured Collection on one side and, on the other,
    # to a Work whose depositor matches the asserted on_behalf_of NUID. The
    # rescue is a safety net for that scoping (a misconfigured showcase, or an
    # on_behalf_of/depositor mismatch), not the expected path: the Work is
    # already deposited and intact by the time it can fire, so only the
    # promotion failed. @publish_link_failed lets #create say exactly that,
    # rather than a false "published" notice or a 403 page hiding a Work the
    # depositor can already see.
    def promote_to_showcase(showcase_id)
      AtlasRb::System::Work.add_linked_member(@work.id, showcase_id, on_behalf_of: current_user&.nuid)
    rescue AtlasRb::ForbiddenError => e
      Rails.logger.warn("[publish] add_linked_member forbidden for work #{@work.id} " \
                        "-> #{showcase_id}: #{e.message}")
      @publish_link_failed = true
    end

    # Shared tail of both deposit branches: seed the title via the structure-safe
    # MODS merge (raw mods_xml=, not the flat plain_title= setter — see
    # save_descriptive!), apply the parent Collection's derivative-permission
    # default (no-op when it has no Sentinel), stage the upload, and enqueue
    # ingest. The gate is set before derivatives exist; Atlas stores the policy
    # and applies it when the async renditions arrive.
    def finalize_new_work(file, collection_id)
      save_descriptive!('Work', @work.id, title: file.original_filename, description: nil)
      Sentinel.apply_default(collection_id, @work.id)
      staged_path = stage_upload(file, @work.id)
      enqueue_ingest_jobs(file, staged_path)
    end

    # Reject-at-upload gate (called before the Work is created): an A/V file
    # whose codec is outside the streaming safe set (H.264 8-bit / AAC / MP3)
    # never enters the repository — depositors normalise before deposit. Wrong
    # *containers* are fine (remuxed downstream by MediaRenditionJob); only the
    # codec is gated. No-op when ffmpeg isn't on the image — degrade, never block.
    def unsupported_av?(file)
      return false unless file

      path = file.tempfile.path.presence || file.path
      mime = Marcel::MimeType.for(Pathname.new(path), name: file.original_filename).to_s
      return false unless mime.start_with?('video/', 'audio/')
      return false unless Ffprobe.available?

      !Ffprobe.safe?(path)
    end
end
