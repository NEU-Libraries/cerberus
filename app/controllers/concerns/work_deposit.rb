# frozen_string_literal: true

# The two branches of the weighted deposit fork — workspace vs publish — and
# the shared tail that finalizes a freshly created Work. Pulled out of
# WorksController so the controller stays focused on request wiring; the branch
# helpers lean on the controller's own deposit_attribution / stage_upload /
# enqueue_ingest_jobs and on DepositorContext for the publish target.
module WorkDeposit
  extend ActiveSupport::Concern

  private

    # Workspace deposit: the Work lives structurally in one of the depositor's
    # own Collections (the picked one, or a parent_id deep-link). Public-but-
    # unpromoted — never wired into a community showcase. The original deposit
    # path, unchanged but for where the parent comes from.
    def create_in_workspace(file)
      parent = AtlasRb::Collection.find(params[:workspace_collection_id].presence || params[:parent_id])
      @work = AtlasRb::Work.create(parent.id, depositor: deposit_attribution(parent))
      finalize_new_work(file)
    end

    # Publish deposit: the Work is homed structurally in the depositor's Person
    # personal-root Collection (so it stays in *their* space, never moved), then
    # surfaced into the chosen community genre showcase via a linked-member edge
    # (the conduit). The +target+ ({ root_id:, showcase_id: }) is resolved and
    # guarded by WorksController#create (publish_target) before we get here.
    def create_published(file, target)
      @work = AtlasRb::Work.create(target[:root_id], depositor: current_user&.nuid)
      finalize_new_work(file)
      AtlasRb::Work.add_linked_member(@work.id, target[:showcase_id])
    end

    # Shared tail of both deposit branches: seed the title via the structure-safe
    # MODS merge (raw mods_xml=, not the flat plain_title= setter — see
    # save_descriptive!), stage the upload, and enqueue ingest.
    def finalize_new_work(file)
      save_descriptive!('Work', @work.id, title: file.original_filename, description: nil)
      staged_path = stage_upload(file, @work.id)
      enqueue_ingest_jobs(file, staged_path)
    end
end
