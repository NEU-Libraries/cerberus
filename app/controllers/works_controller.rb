# frozen_string_literal: true

class WorksController < ApplicationController
  include Thumbable
  include Transformable

  IN_PROGRESS_NOTICE = 'This work is still being processed and cannot be edited yet.'

  before_action :authorize_show!, only: [:downloads]
  before_action :authorize_edit!, only: [:edit, :metadata, :update_metadata]
  before_action :authorize_tombstone!, only: [:tombstone]
  before_action :reject_if_in_progress, only: [:edit]

  def show
    @work = AtlasRb::Work.find(params[:id])
    return render_gone(@work) if @work.tombstoned

    authorize_show!
    flash.now[:alert] = IN_PROGRESS_NOTICE if @work.in_progress
    prepare_show_view
  end

  def tombstone
    AtlasRb::Work.tombstone(params[:id])
    redirect_to root_path, notice: 'Work deleted.'
  end

  def downloads
    @files = AtlasRb::Work.assets(params[:id])
    render layout: false
  end

  def new
    @work = Work.new
    @parent = AtlasRb::Collection.find(params[:parent_id]) if params[:parent_id].present?
  end

  def edit
    @work = AtlasRb::Work.find(params[:id])
    form_preparation(@permissions)
    load_descriptive!('Work')
    load_advanced!('Work')
    breadcrumbs(params[:id], editing: true)
  end

  def create
    file = params[:binary]
    parent = AtlasRb::Collection.find(params[:parent_id])
    @work = AtlasRb::Work.create(parent.id, depositor: deposit_attribution(parent))
    # Seed the initial title via the structure-safe MODS merge (raw mods_xml=),
    # not the flat plain_title= setter — see save_descriptive!.
    save_descriptive!('Work', @work.id, title: file.original_filename, description: nil)

    staged_path = stage_upload(file, @work.id)
    enqueue_ingest_jobs(file, staged_path)

    redirect_to metadata_work_path(@work.id), notice: 'File uploaded — please review the metadata.'
  end

  # Metadata + Permissions tabs are separate forms that both PATCH here with
  # disjoint fields; descriptive edits are merged into the existing MODS in place
  # (MODSMerge) so curated title structure is never flattened. Title + at least
  # one keyword are required.
  def update
    handle_metadata_update(klass: 'Work', resource_key: :work, keywords: true)
  end

  def metadata
    @work = AtlasRb::Work.find(params[:id])
    # Gates the opt-in Image Derivatives section (nil for non-image deposits).
    @image_probe = StagedImageProbe.call(work_id: params[:id])
    form_preparation(@permissions)
    load_descriptive!('Work')
  end

  def update_metadata
    process_derivative_widths
    handle_metadata_update(klass: 'Work', resource_key: :work, keywords: true)
  end

  private

    DERIVATIVES_SKIPPED_NO_IMAGE =
      'Download sizes were skipped: no staged image was found for this work.'

    # Server backstop for the metadata page's opt-in download sizes. The
    # Stimulus controller is the primary enforcement, so a violation here
    # means JS-off or tampering — in that case the metadata still saves and
    # only the optional derivatives are skipped, with the reason flashed
    # (never bounce the whole form over decoration). Known interplay: if
    # descriptive validation also fails, apply_descriptive overwrites this
    # flash (last writer wins) — acceptable; valid derivatives enqueued
    # here are independent of the title and harmless.
    def process_derivative_widths
      raw = params[:derivative_widths]
      return unless raw.is_a?(ActionController::Parameters)

      probe = StagedImageProbe.call(work_id: params[:id])
      return flash[:alert] = DERIVATIVES_SKIPPED_NO_IMAGE if probe.nil?

      result = DerivativeWidths.call(raw: raw.permit(:small, :medium, :large).to_h,
                                     longest_edge: probe.longest_edge)
      unless result.valid?
        return flash[:alert] = "Download sizes were not generated: #{result.error} " \
                               'Your other changes were saved — revisit this page to configure download sizes.'
      end
      return if result.widths.empty?

      DepositDerivativesJob.perform_later(params[:id], result.widths)
    end

    # Resolve the depositor NUID for a new Work.
    #
    # During an acting-as session this is PURE IMPERSONATION: the Work is
    # attributed wholly to the target (depositor = target; proxy_uploader is
    # left empty server-side, so the resource reads exactly as if the target
    # deposited it). The operating admin's hand is recorded in the AuditEvent
    # (actor = admin, on_behalf_of = target), not stamped on the Work. The
    # piece-3 proxy radio is hidden while acting-as (see works/new), so this
    # branch wins unconditionally and the radio value is irrelevant.
    #
    # Outside acting-as, the deposit form's "upload as" radio governs:
    # `"proxy"` → attribute to the collection's configured depositor (the
    # acting user becomes proxy_uploader server-side); any other value
    # (including the default `"myself"`) explicitly attributes to the acting
    # user — passing nil would let Atlas fall through to the collection's
    # configured depositor, silently flipping "myself" into a collection-
    # default attribution on collections that have one set.
    def deposit_attribution(parent)
      return acting_as_nuid if acting_as?
      return parent['depositor'].presence if params[:upload_as] == 'proxy'

      current_user&.nuid
    end

    def prepare_show_view
      @mods = AtlasRb::Work.mods(params[:id], 'html')
      @files = AtlasRb::Work.assets(params[:id])
      @can_tombstone = current_ability.can?(:tombstone,
                                            solr_doc_from_permissions(@permissions, klass: 'Work'))
      breadcrumbs(params[:id])
    end

    # TODO: add support for pdf/word thumbnails — only images get IIIF derivatives today.
    # No derivative_widths here: deposits get thumbnails only at upload time.
    # Small/medium/large are opt-in download renditions chosen on the metadata
    # page's checkbox/slider section, which arrives post-hoc via
    # DepositDerivativesJob (see #process_derivative_widths) — not through
    # this call.
    def enqueue_ingest_jobs(file, staged_path)
      IiifAssetsJob.perform_later(@work.id, staged_path) if file.content_type.to_s.start_with?('image/')
      ContentCreationJob.perform_later(@work.id, staged_path, file.original_filename, SecureRandom.uuid)
    end

    def reject_if_in_progress
      return unless AtlasRb::Work.find(params[:id]).in_progress

      redirect_to work_path(params[:id]), alert: IN_PROGRESS_NOTICE
    end

    def stage_upload(file, work_id)
      dir = File.join(Rails.application.config.x.cerberus.uploads_root, work_id.to_s)
      FileUtils.mkdir_p(dir)
      dest = File.join(dir, file.original_filename)
      FileUtils.cp(file.tempfile.path.presence || file.path, dest)
      dest
    end
end
