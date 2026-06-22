# frozen_string_literal: true

class WorksController < ApplicationController
  include Thumbable
  include Transformable
  include DepositorContext
  include WorkDeposit
  # The weighted deposit fork's context queries (the depositor's own workspace
  # Collections, a community's publish showcases via ShowcaseFinder) run through
  # the Blacklight SearchBuilder, so this controller needs the catalog config —
  # the same wiring Admin::PeopleController uses for its community picker.
  include Blacklight::Configurable

  copy_blacklight_config_from(CatalogController)

  IN_PROGRESS_NOTICE = 'This work is still being processed and cannot be edited yet.'
  PUBLISH_UNAVAILABLE = 'That publish destination is unavailable. ' \
                        'Please try again or deposit to your workspace.'

  before_action :authorize_show!, only: [:downloads, :manifest]
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

  # IIIF Presentation 3.0 manifest — one Canvas per page FileSet, in page
  # order. Read-gated like every other view of the Work; the underlying
  # Atlas reads are caller-gated too.
  def manifest
    work = AtlasRb::Work.find(params[:id])
    return head :not_found if work.tombstoned

    pages = AtlasRb::Work.file_sets(params[:id])
    render json: IiifManifest.call(work: work, pages: pages, url: manifest_work_url(params[:id]))
  end

  def downloads
    @files = AtlasRb::Work.assets(params[:id])
    render layout: false
  end

  # The weighted deposit fork: the first, equal-weight choice is workspace
  # (deposit into one of the depositor's own Collections) vs publish (promote
  # into a community genre showcase). The publish branch is offered only when
  # the depositor has a curated Person with at least one affiliated community
  # that has showcases AND a personal-root Collection to structurally home the
  # work in — see #publish_targets. A parent_id deep-link (from a Collection
  # breadcrumb) pre-selects that collection in the workspace branch.
  def new
    @work = Work.new
    @parent = AtlasRb::Collection.find(params[:parent_id]) if params[:parent_id].present?
    @workspace_collections = workspace_collections
    @publish_targets = publish_targets
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

    if params[:deposit_to] == 'publish'
      target = publish_target
      return redirect_to(new_work_path, alert: PUBLISH_UNAVAILABLE) unless target

      create_published(file, target)
    else
      create_in_workspace(file)
    end

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
    handle_metadata_update(klass: 'Work', resource_key: :work, keywords: true)
    # AFTER the descriptive save, deliberately: with a live worker,
    # DepositDerivativesJob can execute within this same request, and its
    # Delegate PATCH bumps the Work's optimistic lock — enqueueing first
    # raced save_descriptive! into AtlasRb::StaleResourceError (seen live;
    # invisible to specs, whose test adapter never runs the job inline).
    process_derivative_widths
  end

  private

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
      return flash[:alert] = 'Download sizes were skipped: no staged image was found for this work.' if probe.nil?

      enqueue_valid_widths(raw, probe)
    end

    def enqueue_valid_widths(raw, probe)
      result = DerivativeWidths.call(raw:          raw.permit(:small, :medium, :large).to_h,
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
      # The page-turning viewer mounts only for multipage works: two or
      # more positioned page FileSets (the ordered listing is the signal).
      @multipage = AtlasRb::Work.file_sets(params[:id])
                                .count { |page| page['position'].present? } >= 2
      @can_tombstone = current_ability.can?(:tombstone,
                                            solr_doc_from_permissions(@permissions, klass: 'Work'))
      breadcrumbs(params[:id])
    end

    # Per-type enrichment routing (thumbnails, PDF renditions) lives in
    # IngestDispatch, shared with the XML loader. No derivative_widths from
    # this path: small/medium/large are opt-in download renditions chosen on
    # the metadata page's checkbox/slider section, which arrives post-hoc via
    # DepositDerivativesJob (see #process_derivative_widths).
    def enqueue_ingest_jobs(file, staged_path)
      IngestDispatch.call(work_id: @work.id, staged_path: staged_path,
                          original_filename: file.original_filename,
                          idempotency_key: SecureRandom.uuid)
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
