# frozen_string_literal: true

# Creating a Work at its destination, optional promotion into a community
# showcase, and the shared tail that finalizes a freshly created Work. Leans on
# WorksController's own deposit_attribution / stage_upload / enqueue_ingest_jobs
# and on DepositorContext. See docs/deposit.md.
module WorkDeposit
  extend ActiveSupport::Concern

  private

    # The Work lives where the depositor navigated; nothing later moves it.
    def create_at_destination(file)
      parent = AtlasRb::Collection.find(@destination_id)
      raise ResourceNotFound if parent.nil?

      @work = AtlasRb::Work.create(parent.id, depositor: deposit_attribution(parent))
      finalize_new_work(file, parent.id)
    end

    # Keys on the DESTINATION being the depositor's own personal root, not on
    # which button you arrived by, so it can't be sidestepped by typing a URL.
    # See docs/deposit.md.
    def publish_offered?
      root = deposit_person&.[]('personal_root_id').presence
      root.present? && root.to_s == @destination_id.to_s
    end

    # A promotion that can't be honoured leaves the deposit standing and flags
    # the flash: the Work is already placed, so there is nothing to roll back.
    def promote_if_requested
      return unless ActiveModel::Type::Boolean.new.cast(params[:publish])
      return refuse_promotion('not_personal_root') unless publish_offered?

      showcase_id = publish_showcase_id
      return refuse_promotion('no_showcase') if showcase_id.blank?

      promote_to_showcase(showcase_id)
    end

    def refuse_promotion(reason)
      @publish_link_failed = true
      record_promotion(outcome: 'refused', reason: reason)
    end

    # The rescue is a safety net for Atlas's :system scoping, not the expected
    # path: the Work is deposited and intact by the time it can fire, so only
    # the promotion failed and @publish_link_failed must say exactly that —
    # never a 403 page hiding a Work the depositor can already see.
    def promote_to_showcase(showcase_id)
      AtlasRb::System::Work.add_linked_member(@work.id, showcase_id, on_behalf_of: current_user&.nuid)
      record_promotion(outcome: 'promoted', showcase_id: showcase_id)
    rescue AtlasRb::ForbiddenError => e
      Rails.logger.warn("[publish] add_linked_member forbidden for work #{@work.id} " \
                        "-> #{showcase_id}: #{e.message}")
      @publish_link_failed = true
      record_promotion(outcome: 'refused', reason: 'atlas_forbidden', showcase_id: showcase_id)
    end

    # EVERY promotion attempt reaches the admin ledger, refusals included — a
    # refusal is otherwise invisible to everyone but the depositor's one flash.
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
                        work_title: @deposit_title }
      )
    end

    def promotion_subject(outcome)
      return 'Showcase publication refused' if outcome == 'refused'

      genre = params[:publish_genre].presence
      genre ? %(Published to the “#{genre}” showcase) : 'Published to a showcase'
    end

    # NOT DepositorContext#community_name, which dereferences unguarded: this
    # noid comes straight from the form and can name nothing at all, and a
    # ledger write must never break a deposit that has already succeeded.
    def promotion_community_name(noid)
      return nil if noid.blank?

      AtlasRb::Community.find(noid)&.[]('title').presence
    rescue AtlasRb::Error, Faraday::Error, JSON::ParserError
      nil
    end

    # Shared tail of the deposit: title, derivative default, stage, ingest. The
    # title goes through the structure-safe MODS merge (raw mods_xml=, never the
    # flat plain_title= setter — see save_descriptive!). See docs/deposit.md.
    def finalize_new_work(file, collection_id)
      save_descriptive!('Work', @work.id, title: file.original_filename, description: nil)
      # Held for record_promotion, which runs after this and has no file to read.
      @deposit_title = file.original_filename
      apply_derivative_default(collection_id)
      staged_path = stage_upload(file, @work.id)
      enqueue_ingest_jobs(file, staged_path)
    end

    # Never raise: the Work and its file already exist here, so a default Atlas
    # refuses must not abandon a half-made deposit on the error page. Never
    # silent either — skipping it leaves renditions WIDER than intended, which
    # is why the flag rides back to the depositor. See docs/deposit.md.
    def apply_derivative_default(collection_id)
      Sentinel.apply_default(collection_id, @work.id)
    rescue AtlasRb::DerivativePermissionsError => e
      Rails.logger.error("[deposit] derivative default rejected for work #{@work.id} " \
                         "under collection #{collection_id}: #{e.message}")
      @derivative_default_failed = true
    end

    # Reject-at-upload gate, called BEFORE the Work is created. Only the codec
    # is gated (H.264 8-bit / AAC / MP3); wrong containers are fine and are
    # remuxed downstream by MediaRenditionJob. No-op without ffmpeg on the
    # image — degrade, never block. See docs/deposit.md.
    def unsupported_av?(file)
      return false unless file

      path = file.tempfile.path.presence || file.path
      mime = Marcel::MimeType.for(Pathname.new(path), name: file.original_filename).to_s
      return false unless mime.start_with?('video/', 'audio/')
      return false unless Ffprobe.available?

      !Ffprobe.safe?(path)
    end
end
