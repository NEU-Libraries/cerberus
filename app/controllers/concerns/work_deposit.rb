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
    # Promotion is offered only when the destination IS the depositor's own
    # personal root. That is what keeps a promoted Work in the depositor's own
    # space now that the route, not the publish branch, decides placement — and
    # it keys on the destination rather than on which button you arrived by, so
    # it can't be sidestepped by typing a URL.
    def publish_offered?
      root = deposit_person&.[]('personal_root_id').presence
      root.present? && root.to_s == @destination_id.to_s
    end

    # Add the showcase edge when the form asked for one. A promotion that can't
    # be honoured leaves the deposit standing and flags the flash — the Work
    # already exists and is correctly placed, so there is nothing to roll back.
    def promote_if_requested
      return unless ActiveModel::Type::Boolean.new.cast(params[:publish])
      # The destination is not the depositor's own root, so the form never
      # offered promotion here — a typed URL, or a tampered field.
      return refuse_promotion('not_personal_root') unless publish_offered?

      showcase_id = publish_showcase_id
      # No showcase exists for that genre in that community, or the depositor
      # cannot see the one that does.
      return refuse_promotion('no_showcase') if showcase_id.blank?

      promote_to_showcase(showcase_id)
    end

    def refuse_promotion(reason)
      @publish_link_failed = true
      record_promotion(outcome: 'refused', reason: reason)
    end

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
      record_promotion(outcome: 'promoted', showcase_id: showcase_id)
    rescue AtlasRb::ForbiddenError => e
      Rails.logger.warn("[publish] add_linked_member forbidden for work #{@work.id} " \
                        "-> #{showcase_id}: #{e.message}")
      @publish_link_failed = true
      record_promotion(outcome: 'refused', reason: 'atlas_forbidden', showcase_id: showcase_id)
    end

    # Every promotion attempt reaches the admin ledger, refusals included.
    #
    # A showcase is a curated public surface that nobody approves onto, so staff
    # read the list afterwards to catch a work promoted that belongs on no
    # showcase at all, or filed under the wrong genre. That is why it carries
    # every attempt rather than only the anomalies.
    #
    # A refusal is the outcome nobody else can see. The Work deposits correctly,
    # the depositor gets one flash and moves on, and the showcase silently does
    # not gain it — so without this row, only a log line records that somebody
    # asked to publish and did not.
    def record_promotion(outcome:, reason: nil, showcase_id: nil)
      community_noid = params[:publish_community_id].presence
      AdminNotice.create!(
        kind:         'showcase_promotion',
        subject:      promotion_subject(outcome),
        actor_nuid:   current_user&.nuid,
        subject_noid: @work&.id,
        payload:      { outcome: outcome, reason: reason, showcase_noid: showcase_id,
                        community_noid: community_noid, genre: params[:publish_genre].presence,
                        community_name: promotion_community_name(community_noid),
                        # The filename the deposit was titled with — the strongest
                        # wrong-genre signal available, and free. A .pptx filed
                        # under "Datasets" reads wrong at a glance. It is a
                        # snapshot: a later rename leaves it alone, which for a
                        # review list is what you want to see.
                        work_title: @deposit_title }
      )
    end

    def promotion_subject(outcome)
      return 'Showcase publication refused' if outcome == 'refused'

      genre = params[:publish_genre].presence
      genre ? %(Published to the “#{genre}” showcase) : 'Published to a showcase'
    end

    # Resolved here rather than through DepositorContext#community_name, which
    # assumes a real affiliation and dereferences the resource unguarded. This
    # noid comes straight from the form, so it can name nothing at all — and a
    # ledger write must never break a deposit that has already succeeded.
    def promotion_community_name(noid)
      return nil if noid.blank?

      AtlasRb::Community.find(noid)&.[]('title').presence
    rescue AtlasRb::Error, Faraday::Error, JSON::ParserError
      nil
    end

    # Shared tail of both deposit branches: seed the title via the structure-safe
    # MODS merge (raw mods_xml=, not the flat plain_title= setter — see
    # save_descriptive!), apply the parent Collection's derivative-permission
    # default (no-op when it has no Sentinel), stage the upload, and enqueue
    # ingest. The gate is set before derivatives exist; Atlas stores the policy
    # and applies it when the async renditions arrive.
    def finalize_new_work(file, collection_id)
      save_descriptive!('Work', @work.id, title: file.original_filename, description: nil)
      # Held for the showcase-promotion notice, which runs after this and has no
      # file of its own to read the title from.
      @deposit_title = file.original_filename
      apply_derivative_default(collection_id)
      staged_path = stage_upload(file, @work.id)
      enqueue_ingest_jobs(file, staged_path)
    end

    # The collection's derivative-access default, applied to the new Work.
    #
    # Atlas refuses a tier more visible than its Work, so a default naming an
    # audience the Work does not have is rejected. That should not happen — the
    # authoring form checks the default against its collection, and a visibility
    # cascade re-clamps it — but the deposit must not die on the Rails error page
    # if it ever does again: the Work and its file already exist by this point, so
    # raising abandoned a half-made deposit and told the depositor nothing.
    #
    # Not silent, though. The default exists to make renditions MORE restrictive
    # than the Work, so skipping it leaves them at the Work's own audience — wider
    # than intended, and the depositor is the one who needs to know.
    def apply_derivative_default(collection_id)
      Sentinel.apply_default(collection_id, @work.id)
    rescue AtlasRb::DerivativePermissionsError => e
      Rails.logger.error("[deposit] derivative default rejected for work #{@work.id} " \
                         "under collection #{collection_id}: #{e.message}")
      @derivative_default_failed = true
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
