# frozen_string_literal: true

# Spans the whole Work lifecycle — deposit, show, edit, tombstone, manifest,
# downloads — as one cohesive controller rather than being split by verb, which
# is why it runs past the default class-length budget. See docs/deposit.md.
class WorksController < ApplicationController # rubocop:disable Metrics/ClassLength
  include Thumbable
  include Transformable
  include DepositorContext
  include WorkDeposit
  include WorkBreadcrumbs
  include WorkChangeRequest
  include WorkCaptions
  include WorkStreamingOnly
  include WorkDerivativeWidths
  include UploadStaging
  include RecordsImpressions
  include ZoomViewer
  include ParallelAtlasReads
  # The deposit context queries run through the Blacklight SearchBuilder, so
  # this controller needs the catalog config.
  include Blacklight::Configurable
  # `search_service` lives in Searchable, NOT in Blacklight::Controller, and
  # this controller does not inherit from CatalogController.
  include Blacklight::Searchable

  copy_blacklight_config_from(CatalogController)

  IN_PROGRESS_NOTICE = 'This work is still being processed and cannot be edited yet.'
  PUBLISH_LINK_FAILED = "File uploaded — please review the metadata. It couldn't be added to the " \
                        'community showcase; contact DRS staff if this persists.'
  DERIVATIVE_DEFAULT_FAILED = 'File uploaded — please review the metadata. The collection\'s download ' \
                              'restrictions could not be applied to it; contact DRS staff before sharing it.'
  UNSUPPORTED_AV = 'DRS streams H.264/AAC video and AAC/MP3 audio — please convert your file first.'

  before_action :authorize_show!, only: [:downloads, :manifest]
  authorize_resource_writes!(extra_edit: %i[metadata update_metadata request_change upload add_file])
  before_action :reject_if_in_progress, only: [:edit]
  after_action :record_view_impression, only: :show

  # Blacklight 8 scopes every SearchBuilder to the SearchService, not the
  # controller, so without this SearchBuilder#gated_user is nil and the
  # associations box silently gates as anonymous.
  def search_service_context
    { current_user: current_user, effective_user: effective_user }
  end

  def show
    @work = AtlasRb::Work.find(params[:id])
    raise ResourceNotFound if @work.nil?
    return render_gone(@work) if @work.tombstoned

    authorize_show!
    deny_if_unfinished!(@work)
    flash.now[:alert] = IN_PROGRESS_NOTICE if @work.in_progress
    prepare_show_view
  end

  def tombstone
    perform_tombstone!(AtlasRb::Work.tombstone(params[:id]), type: 'Work')
  end

  # IIIF Presentation 3.0 manifest, one Canvas per page FileSet in page order.
  def manifest
    work = AtlasRb::Work.find(params[:id])
    return head :not_found if work.tombstoned

    pages = AtlasRb::Work.file_sets(params[:id])
    render json: IiifManifest.call(work: work, pages: pages, url: manifest_work_url(params[:id]))
  end

  def downloads
    @files = AtlasRb::Work.assets(params[:id], nuid: effective_user&.nuid)
    render layout: false
  end

  # The form asks what to deposit, never where: the destination is the route's
  # parent segment, already :edit-gated by authorize_destination!.
  def new
    @work = Work.new
    @parent = AtlasRb::Collection.find(@destination_id)
    raise ResourceNotFound if @parent.nil?

    # Required: without it form_tag posts back to /collections/:id/works/new,
    # which routes nowhere for POST, and the deposit 404s on submit.
    @create_path = child_create_path('works')
    @publish_targets = publish_offered? ? publish_targets : {}
  end

  def edit
    @work = requested_work
    form_preparation(@permissions, resource: @work)
    load_descriptive!('Work')
    load_advanced!('Work')
    # The Work's own assets, not the staged upload #metadata probes: by edit
    # time the content Blob has landed and the staged file is long gone.
    assets = AtlasRb::Work.assets(params[:id], nuid: effective_user&.nuid)
    load_streaming_only!(offered: StreamingOnly.applicable?(assets))
    load_caption!(offered: CaptionTrack.applicable?(assets), files: assets)
    breadcrumbs(params[:id], editing: true)
  end

  def create
    file = params[:binary]

    return redirect_to(new_child_path('work'), alert: UNSUPPORTED_AV) if unsupported_av?(file)

    create_at_destination(file)
    promote_if_requested

    redirect_to metadata_work_path(@work.id), notice: create_notice
  end

  # The Metadata and Permissions tabs are separate forms that both PATCH here
  # with disjoint fields. See docs/deposit.md.
  def update
    handle_metadata_update(klass: 'Work', resource_key: :work, keywords: true)
    apply_streaming_only!
    apply_caption!
  end

  def metadata
    @work = AtlasRb::Work.find(params[:id])
    @image_probe = StagedImageProbe.call(work_id: params[:id])
    form_preparation(@permissions, resource: @work)
    load_descriptive!('Work')
    # Probe the STAGED file, never the Work's assets: ContentCreationJob may
    # still be in flight here, and Atlas would hide the toggle and the caption
    # field from exactly the deposits that want them.
    video = StagedVideoProbe.call(work_id: params[:id])
    load_streaming_only!(offered: video)
    load_caption!(offered: video)
  end

  def update_metadata
    handle_metadata_update(klass: 'Work', resource_key: :work, keywords: true)
    # AFTER the descriptive save, deliberately: with a live worker
    # DepositDerivativesJob runs inside this request and its Delegate PATCH
    # bumps the lock, racing save_descriptive! into StaleResourceError. Specs
    # never see it — the test adapter does not run the job inline.
    process_derivative_widths
    apply_streaming_only!
    # Before the confirm, so the caption Blob queues behind the deposit's own
    # finalization rather than ahead of it.
    apply_caption!
    # This save is the depositor's confirmation, and confirmation completes the
    # Work; ingest deliberately leaves it in_progress. See docs/deposit.md.
    ConfirmDepositJob.perform_later(params[:id])
  end

  # The "Upload File" affordance on the show page; #add_file handles the POST.
  def upload
    @work = AtlasRb::Work.find(params[:id])
    raise ResourceNotFound if @work.nil?

    upload_breadcrumbs
  end

  # ATTACH-ONLY: never enrich here. The added file appears in Downloads and the
  # Work's thumbnail, viewer and existing files stay untouched. See
  # docs/deposit.md.
  def add_file
    file = params[:binary]
    return redirect_to(upload_work_path(params[:id]), alert: 'Choose a file to upload.') if file.blank?

    staged_path = stage_upload(file, params[:id])
    AddFileJob.perform_later(params[:id], staged_path, file.original_filename, SecureRandom.uuid)
    redirect_to work_path(params[:id]),
                notice: 'File uploaded — it will appear in Downloads once processing finishes.'
  end

  private

    # The acting-as branch wins unconditionally, and must: the proxy radio is
    # hidden while acting-as, so its value is meaningless there. The last line
    # has to name the acting user explicitly — passing nil lets Atlas fall
    # through to the collection's configured depositor, silently flipping
    # "myself" into a collection-default attribution. See docs/deposit.md.
    def deposit_attribution(parent)
      return acting_as_nuid if acting_as?
      return parent['depositor'].presence if params[:upload_as] == 'proxy'

      current_user&.nuid
    end

    def prepare_show_view
      reads = parallel_show_reads
      @mods = reads[:mods]
      @files = reads[:files]
      @scholar = GoogleScholarMetadata.for(work: @work, permissions: @permissions, files: @files)
      @av_file = MediaRemux.playable_file(@files)
      @caption = CaptionTrack.for(@files)
      # On the request thread, never in a worker: the gate is the search
      # service, and a worker holds no database connection.
      @associations = WorkAssociations.call(associations:   reads[:associations],
                                            search_service: search_service)
      prepare_zoom_view(params[:id], pages: reads[:file_sets])
      assign_show_abilities!(klass: 'Work')
      work_breadcrumbs(params[:id])
    end

    # mods deliberately carries no nuid — Current.nuid, the real user, gates it.
    # The view-as NUID is resolved here rather than inside a task because the
    # workers must not touch ActiveRecord. See docs/deposit.md.
    def parallel_show_reads
      viewer_nuid = effective_user&.nuid
      parallel_atlas_reads(
        mods:         -> { AtlasRb::Work.mods(params[:id], 'html') },
        files:        -> { AtlasRb::Work.assets(params[:id], nuid: viewer_nuid) },
        file_sets:    -> { AtlasRb::Work.file_sets(params[:id], nuid: viewer_nuid) },
        associations: -> { associations_or_none(params[:id]) }
      )
    end

    # parallel_atlas_reads re-raises any task's error, so this rescue has to
    # live INSIDE the task; the associations box is supplementary and must not
    # take the page with it. nil reads as "no associations" downstream.
    def associations_or_none(id)
      AtlasRb::Work.associations(id)
    rescue StandardError => e
      Rails.logger.error("WorksController: associations read failed for #{id}: #{e.class} #{e.message}")
      nil
    end

    def create_notice
      return PUBLISH_LINK_FAILED if @publish_link_failed
      return DERIVATIVE_DEFAULT_FAILED if @derivative_default_failed

      'File uploaded — please review the metadata.'
    end

    # complete_work: false — the depositor still owes the metadata page, so
    # ingest must not complete this Work; #update_metadata does, once they save.
    # No derivative_widths from this path either. See docs/ingest.md.
    def enqueue_ingest_jobs(file, staged_path)
      IngestDispatch.call(work_id: @work.id, staged_path: staged_path,
                          original_filename: file.original_filename,
                          idempotency_key: SecureRandom.uuid,
                          complete_work: false)
    end

    # A lock, not housekeeping: it stops a second person editing underneath the
    # depositor still sitting on the metadata page. Gate #edit only — the
    # metadata page rides `extra_edit` and must stay reachable.
    def reject_if_in_progress
      return unless requested_work.in_progress

      redirect_to work_path(params[:id]), alert: IN_PROGRESS_NOTICE
    end

    # Keep the memo: the in-progress gate runs as a before_action and #edit
    # needs the same payload, so without it the edit page reads Atlas twice.
    def requested_work
      @requested_work ||= AtlasRb::Work.find(params[:id])
    end

    # Mirrors ApplicationController#edit_breadcrumb_tail, differing only in the
    # tail label. `match: :exact` keeps loaf from marking the Work crumb current
    # on the /upload sub-path, which is what makes it a link back.
    def upload_breadcrumbs
      Array(@work.ancestors).each do |node|
        add_breadcrumb_for(node['noid'], node['klass'], node['title'])
      end
      breadcrumb(@work.title, work_path(@work.id), match: :exact)
      breadcrumb('Upload File', upload_work_path(@work.id))
    end
end
