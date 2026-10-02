# frozen_string_literal: true

class LoadsController < ApplicationController
  # Borrow CatalogController's Solr config so the XML/multipage destination
  # typeahead's ResourceSearch behaves like the catalog's keyword search (same
  # qf / search fields). ApplicationController's Blacklight::Controller doesn't
  # pull this in on its own — mirrors Admin::ReparentController.
  include Blacklight::Configurable

  copy_blacklight_config_from(CatalogController)

  # "PID" to match this field's own placeholder, the loader form's "Root collection
  # PID" label, and the manifest's PIDs column. The identifier is a NOID in v2, but
  # the interface has settled on v1's word for it, and giving the reader two words
  # for one thing is worse than using the older one consistently.
  BAD_DESTINATION_MSG = 'Choose a destination collection (search by title or paste a collection PID).'
  # IPTC picks from a dropdown, so this refusal means the list changed under the form.
  IPTC_DESTINATION_MSG = 'Choose a destination collection from the list.'

  before_action :authenticate_user!
  before_action :set_loader
  before_action :require_loader_role
  before_action :require_loader_group
  before_action :set_load_report, only: [:show, :destroy, :confirm]

  def index
    @load_reports = LoadReport.where(loader: @loader).order(created_at: :desc)
    flash.now[:notice] = 'Upload canceled.' if params[:canceled]
  end

  def show
    # XML and multipage loads pause on a preview the librarian must confirm;
    # build it lazily from the staged archive (no persistence) for the show
    # view to render.
    @preview = preview_service.call(load_report: @load_report) if shows_preview?
    # Here, not inside XmlPreview: the upload path calls XmlPreview only to ask
    # blocked?, and must not pay for a thumbnail it never shows.
    return unless @preview && @loader.xml? && !@preview.blocked?

    @preview_file = XmlPreviewFile.call(load_report: @load_report, row: @preview.first_row)
  end

  def new
    @load_report  = LoadReport.new
    # IPTC is boxed to its root collection's children (the dropdown). XML and
    # multipage pick any collection via the client-driven typeahead, so they
    # need no precomputed destination list.
    @destinations = @loader.iptc? ? IptcDestinations.call(root: @loader.root_collection) : []
  end

  # JSON typeahead for the XML/multipage destination picker: any collection by
  # title, gated-discovery aware (an admin sees non-public collections). Returns
  # `[{ value: <noid>, label: <title> }]`; fail-soft to [] so it never 500s.
  def collection_search
    documents = ResourceSearch.call(scope: self, query: params[:q], types: %w[Collection]).documents
    render json: LoaderDestinationOptions.call(documents: documents)
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error("LoadsController#collection_search: #{e.class} #{e.message}")
    render json: []
  end

  def create
    archive = params.dig(:load_report, :archive)
    parent  = params.dig(:load_report, :parent_collection_id)
    return rerender_new('Please choose an archive file.', parent) if archive.blank?
    return rerender_new(destination_alert, parent) unless LoadDestination.call(loader: @loader, parent_id: parent)

    @load_report = create_load_report!(archive, parent)
    save_archive(@load_report, archive)
    start_or_hold(@load_report)

    # No flash notice — the show page's own state (in-progress spinner for
    # IPTC, the preview card for XML) communicates what happens next, so a
    # redundant banner would only contradict the body once the poll runs.
    redirect_to loader_load_path(@loader, @load_report)
  rescue ActiveRecord::RecordInvalid
    @destinations = @loader.iptc? ? IptcDestinations.call(root: @loader.root_collection) : []
    render :new, status: :unprocessable_content
  end

  # Librarian-approved go: flip the staged preview into a real run.
  def confirm
    return redirect_to(loader_load_path(@loader, @load_report)) unless @load_report.previewing?
    # The preview hides Confirm when it is blocked; this refuses a hand-sent one,
    # such as a create manifest staged without a destination.
    return redirect_to(loader_load_path(@loader, @load_report)) if xml_preview_blocked?

    @load_report.update!(status: :pending)
    unzip_job.perform_later(@load_report.id)
    redirect_to loader_load_path(@loader, @load_report)
  end

  def destroy
    @load_report.destroy
    # The preview's Discard abandons an upload; the list's Delete removes a run.
    redirect_to loader_loads_path(@loader), notice: params[:discard] ? 'Upload canceled.' : 'Load report deleted.'
  end

  private

    def create_load_report!(archive, parent)
      LoadReport.create!(
        loader:               @loader,
        creator_nuid:         attributed_nuid,
        source_filename:      archive.original_filename,
        parent_collection_id: parent,
        status:               @loader.iptc? ? :pending : :previewing
      )
    end

    # IPTC commits straight to the run. XML and multipage stop at a preview
    # the librarian confirms (see #confirm), so they enqueue no job yet — the
    # show view renders the preview from the staged archive. A blocked preview
    # can never be confirmed, so it is failed now rather than left reading
    # Previewing on the loader's list indefinitely.
    def start_or_hold(load_report)
      return UnzipJob.perform_later(load_report.id) if @loader.iptc?

      load_report.fail_load if preview_service.call(load_report: load_report).blocked?
    end

    def shows_preview?
      @load_report.previewing? || @load_report.failed_at_preview?
    end
    helper_method :shows_preview?

    def xml_preview_blocked?
      @loader.xml? && XmlPreview.call(load_report: @load_report).blocked?
    end

    def preview_service
      @loader.multipage? ? MultipagePreview : XmlPreview
    end

    def unzip_job
      @loader.multipage? ? MultipageUnzipJob : XmlUnzipJob
    end

    # Re-render the upload form with an inline alert, preserving the chosen
    # destination. IPTC repopulates its children dropdown; XML/multipage drive
    # the destination client-side, so they need no precomputed list.
    def rerender_new(alert, parent_id)
      flash.now[:alert] = alert
      @load_report      = LoadReport.new(parent_collection_id: parent_id)
      @destinations     = @loader.iptc? ? IptcDestinations.call(root: @loader.root_collection) : []
      render :new, status: :unprocessable_content
    end

    def destination_alert = @loader.iptc? ? IPTC_DESTINATION_MSG : BAD_DESTINATION_MSG

    def set_loader
      @loader = Loader.find_by(slug: params[:loader_slug])
      render template: 'errors/not_found', status: :not_found, layout: 'application' if @loader.nil?
    end

    def set_load_report
      @load_report = LoadReport.find_by(id: params[:id], loader: @loader)
      render template: 'errors/not_found', status: :not_found, layout: 'application' if @load_report.nil?
    end

    def require_loader_role
      return if effective_user&.loader_tier?

      render template: 'errors/forbidden', status: :forbidden, layout: 'application'
    end

    def require_loader_group
      return if effective_user&.admin?
      return if @loader && effective_user&.groups&.include?(@loader.group)

      render template: 'errors/forbidden', status: :forbidden, layout: 'application'
    end

    # FileUtils.cp against the Rails tempfile path — streaming copy,
    # never File.write(file.read) which would slurp the archive into
    # Ruby memory. Matches WorksController#stage_upload's shape.
    def save_archive(load_report, archive)
      dir = File.join(
        Rails.application.config.x.cerberus.uploads_root,
        'load_reports',
        load_report.id.to_s
      )
      FileUtils.mkdir_p(dir)
      dest = File.join(dir, archive.original_filename)
      FileUtils.cp(archive.tempfile&.path.presence || archive.path, dest)
    end
end
