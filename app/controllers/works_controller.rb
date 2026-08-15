# frozen_string_literal: true

# Spans the whole Work lifecycle — deposit, show, edit, tombstone, manifest,
# downloads — as one cohesive controller rather than being split by verb, so it
# runs past the default class-length budget.
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
  # The weighted deposit fork's context queries (the depositor's own workspace
  # Collections, a community's publish showcases via ShowcaseFinder) run through
  # the Blacklight SearchBuilder, so this controller needs the catalog config —
  # the same wiring Admin::PeopleController uses for its community picker.
  include Blacklight::Configurable
  # Blacklight::Controller supplies search_state and the config; `search_service`
  # itself lives in Searchable, which CatalogController's subclasses get by
  # inheritance and this controller does not. The associations box needs it to
  # resolve its edges through the gated search.
  include Blacklight::Searchable

  copy_blacklight_config_from(CatalogController)

  IN_PROGRESS_NOTICE = 'This work is still being processed and cannot be edited yet.'
  # Covers both promotion failures — an unresolvable showcase and a refused
  # link. Either way the deposit itself succeeded, which is what the depositor
  # needs to know; the distinction only matters in the log.
  PUBLISH_LINK_FAILED = "File uploaded — please review the metadata. It couldn't be added to the " \
                        'community showcase; contact DRS staff if this persists.'
  # The deposit stands; only the collection's per-rendition default was refused,
  # which leaves this work's renditions at its own visibility rather than the
  # narrower one the collection asked for. Named to the depositor because that is
  # wider access than intended, even though it is never wider than the work.
  DERIVATIVE_DEFAULT_FAILED = 'File uploaded — please review the metadata. The collection\'s download ' \
                              'restrictions could not be applied to it; contact DRS staff before sharing it.'
  UNSUPPORTED_AV = 'DRS streams H.264/AAC video and AAC/MP3 audio — please convert your file first.'

  before_action :authorize_show!, only: [:downloads, :manifest]
  authorize_resource_writes!(extra_edit: %i[metadata update_metadata request_change upload add_file])
  before_action :reject_if_in_progress, only: [:edit]
  after_action :record_view_impression, only: :show

  # Plumb the acting user into the search service, as CatalogController does for
  # its own subtree. Blacklight 8 scopes every SearchBuilder to the
  # SearchService rather than the controller, so without this
  # SearchBuilder#gated_user is nil and the associations box would silently gate
  # as anonymous — hiding a viewer's own restricted associated Works from them.
  # `effective_user` honours a view-as session.
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
    @files = AtlasRb::Work.assets(params[:id], nuid: effective_user&.nuid)
    render layout: false
  end

  # The form asks what to deposit, never where: the destination is the route's
  # parent segment, already resolved and :edit-gated by authorize_destination!.
  # Its one option is promotion into a community genre showcase, offered only
  # from the depositor's own personal root — see #publish_offered?.
  def new
    @work = Work.new
    @parent = AtlasRb::Collection.find(@destination_id)
    raise ResourceNotFound if @parent.nil?

    # The POST target for the form this renders. Without it form_tag falls back
    # to the current URL — /collections/:id/works/new, which routes nowhere for
    # POST — and the deposit 404s on submit.
    @create_path = child_create_path('works')
    @publish_targets = publish_offered? ? publish_targets : {}
  end

  def edit
    @work = AtlasRb::Work.find(params[:id])
    form_preparation(@permissions, resource: @work)
    load_descriptive!('Work')
    load_advanced!('Work')
    # Decided off the Work's own assets here: by edit time the content Blob has
    # landed, and the staged upload the deposit page probes is long gone.
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

  # Metadata + Permissions tabs are separate forms that both PATCH here with
  # disjoint fields; descriptive edits are merged into the existing MODS in place
  # (MODSMerge) so curated title structure is never flattened. Title + at least
  # one keyword are required.
  def update
    handle_metadata_update(klass: 'Work', resource_key: :work, keywords: true)
    apply_streaming_only!
    apply_caption!
  end

  def metadata
    @work = AtlasRb::Work.find(params[:id])
    # Gates the opt-in Image Derivatives section (nil for non-image deposits).
    @image_probe = StagedImageProbe.call(work_id: params[:id])
    form_preparation(@permissions, resource: @work)
    load_descriptive!('Work')
    # The staged file, not the Work's assets: ContentCreationJob may still be in
    # flight when this page renders, and asking Atlas would hide the toggle and
    # the caption field from exactly the deposits that want them. Probed once and
    # shared, since both sections ask the same question of the same upload.
    video = StagedVideoProbe.call(work_id: params[:id])
    load_streaming_only!(offered: video)
    load_caption!(offered: video)
  end

  def update_metadata
    handle_metadata_update(klass: 'Work', resource_key: :work, keywords: true)
    # AFTER the descriptive save, deliberately: with a live worker,
    # DepositDerivativesJob can execute within this same request, and its
    # Delegate PATCH bumps the Work's optimistic lock — enqueueing first
    # raced save_descriptive! into AtlasRb::StaleResourceError (seen live;
    # invisible to specs, whose test adapter never runs the job inline).
    process_derivative_widths
    apply_streaming_only!
    # Before the confirm below, so the caption Blob is queued behind the deposit's
    # own finalization rather than ahead of it. CaptionJob waits for the primary
    # file regardless — see the job, which explains why it must.
    apply_caption!
    # This save is the depositor confirming the deposit, and confirmation is what
    # completes the Work — ingest deliberately leaves it in_progress. Deferred to a
    # job because Atlas asks callers to complete only once the expected children
    # are deposited, and the primary Blob may still be in flight.
    ConfirmDepositJob.perform_later(params[:id])
  end

  # The "Upload File" affordance on the show page: add an arbitrary binary to
  # this already-complete Work. GET renders the form; #add_file handles the POST.
  def upload
    @work = AtlasRb::Work.find(params[:id])
    raise ResourceNotFound if @work.nil?

    upload_breadcrumbs
  end

  # Attach the uploaded binary as an additional download. The file is staged to
  # disk and the Blob create is deferred to AddFileJob so the request returns
  # immediately (the upload may be multi-GB). Attach-only: no derivative
  # enrichment, so the Work's thumbnail / viewer / existing files are untouched —
  # the added file simply appears in the Downloads card once processing finishes.
  def add_file
    file = params[:binary]
    return redirect_to(upload_work_path(params[:id]), alert: 'Choose a file to upload.') if file.blank?

    staged_path = stage_upload(file, params[:id])
    AddFileJob.perform_later(params[:id], staged_path, file.original_filename, SecureRandom.uuid)
    redirect_to work_path(params[:id]),
                notice: 'File uploaded — it will appear in Downloads once processing finishes.'
  end

  private

    # Resolve the depositor NUID for a new Work.
    #
    # During an acting-as session this is PURE IMPERSONATION: the Work is
    # attributed wholly to the target (depositor = target; proxy_uploader is
    # left empty server-side, so the resource reads exactly as if the target
    # deposited it). The operating admin's hand is recorded in the AuditEvent
    # (actor = admin, on_behalf_of = target), not stamped on the Work. The
    # proxy radio is hidden while acting-as (see works/new), so this
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
      reads = parallel_show_reads
      @mods = reads[:mods]
      @files = reads[:files]
      @scholar = GoogleScholarMetadata.for(work: @work, permissions: @permissions, files: @files)
      @av_file = MediaRemux.playable_file(@files)
      @caption = CaptionTrack.for(@files)
      # Resolved on the request thread, not in the worker: the gate is the
      # search service, which reads the acting user, and a worker holds no
      # database connection.
      @associations = WorkAssociations.call(associations:   reads[:associations],
                                            search_service: search_service)
      prepare_zoom_view(params[:id], pages: reads[:file_sets])
      assign_show_abilities!(klass: 'Work')
      work_breadcrumbs(params[:id])
    end

    # The show page's four independent Atlas reads, run concurrently. mods carries
    # no nuid (gated by Current.nuid, the real user); assets and file_sets gate on
    # the effective (view-as) user, resolved here on the request thread because the
    # workers must not touch ActiveRecord.
    def parallel_show_reads
      viewer_nuid = effective_user&.nuid
      parallel_atlas_reads(
        mods:         -> { AtlasRb::Work.mods(params[:id], 'html') },
        files:        -> { AtlasRb::Work.assets(params[:id], nuid: viewer_nuid) },
        file_sets:    -> { AtlasRb::Work.file_sets(params[:id], nuid: viewer_nuid) },
        associations: -> { associations_or_none(params[:id]) }
      )
    end

    # The associations box is supplementary, so a failed read must not take the
    # page with it — unlike mods / assets / file_sets, which it cannot render
    # without. parallel_atlas_reads re-raises any task's error, so the rescue
    # belongs inside the task. nil reads as "no associations" downstream.
    def associations_or_none(id)
      AtlasRb::Work.associations(id)
    rescue StandardError => e
      Rails.logger.error("WorksController: associations read failed for #{id}: #{e.class} #{e.message}")
      nil
    end

    # Both post-deposit steps that can fail without failing the deposit itself.
    # Each names what did not happen; neither hides that the file is in.
    def create_notice
      return PUBLISH_LINK_FAILED if @publish_link_failed
      return DERIVATIVE_DEFAULT_FAILED if @derivative_default_failed

      'File uploaded — please review the metadata.'
    end

    # Per-type enrichment routing (thumbnails, PDF renditions) lives in
    # IngestDispatch, shared with the XML loader. No derivative_widths from
    # this path: small/medium/large are opt-in download renditions chosen on
    # the metadata page's checkbox/slider section, which arrives post-hoc via
    # DepositDerivativesJob (see #process_derivative_widths).
    # complete_work: false — the depositor still owes the metadata page, so
    # ingest must not complete this Work. #update_metadata does, once they save.
    def enqueue_ingest_jobs(file, staged_path)
      IngestDispatch.call(work_id: @work.id, staged_path: staged_path,
                          original_filename: file.original_filename,
                          idempotency_key: SecureRandom.uuid,
                          complete_work: false)
    end

    # A lock, not housekeeping: an unfinished deposit is probably open on its
    # depositor's screen at the metadata page, and this stops a second person
    # editing underneath them. The metadata page itself stays reachable to anyone
    # with edit rights (it rides `extra_edit`), so an abandoned deposit can always
    # be finished or withdrawn.
    def reject_if_in_progress
      return unless AtlasRb::Work.find(params[:id]).in_progress

      redirect_to work_path(params[:id]), alert: IN_PROGRESS_NOTICE
    end

    # Trail for the upload form: the Work's structural ancestors, then the Work
    # itself as a link back to its show page (match: :exact so loaf doesn't mark
    # it current on the /upload sub-path), then a final "Upload File" you-are-here
    # crumb. Mirrors ApplicationController#edit_breadcrumb_tail, differing only in
    # the tail label — an editor can back out to the Work via the trail.
    def upload_breadcrumbs
      Array(@work.ancestors).each do |node|
        add_breadcrumb_for(node['noid'], node['klass'], node['title'])
      end
      breadcrumb(@work.title, work_path(@work.id), match: :exact)
      breadcrumb('Upload File', upload_work_path(@work.id))
    end
end
