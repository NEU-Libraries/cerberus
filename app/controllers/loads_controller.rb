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
    results = ResourceSearch.call(scope: self, query: params[:q], types: %w[Collection])
    render json: results.documents.map { |doc|
      { value: doc.to_param, label: Array(doc['title_tsim']).first.presence || '(untitled)' }
    }
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error("LoadsController#collection_search: #{e.class} #{e.message}")
    render json: []
  end

  def create
    archive = params.dig(:load_report, :archive)
    parent  = params.dig(:load_report, :parent_collection_id)
    return rerender_new('Please choose an archive file.', parent) if archive.blank?
    return rerender_new(BAD_DESTINATION_MSG, parent) unless valid_destination?(parent)

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
    notice = params[:discard].present? ? 'Upload canceled.' : 'Load report deleted.'
    redirect_to loader_loads_path(@loader), notice: notice
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

    # IPTC's destination comes from the children dropdown (already a collection
    # under the configured root), so it's trusted as-is. XML/multipage accept a
    # free-typed or typeahead-picked NOID, so resolve it against Atlas and
    # confirm it's actually a Collection before staging anything.
    # A blank destination is left to the preview on the XML loader: an overwrite
    # package names every Work it touches, and only a create row needs one.
    def valid_destination?(parent_id)
      return true if @loader.iptc?
      return @loader.xml? if parent_id.blank?

      # find returns nil for a 404 (unknown NOID) and raises ResourceError for
      # any other non-2xx; either way the destination isn't a usable Collection.
      AtlasRb::Resource.find(parent_id)&.klass == 'Collection'
    rescue Faraday::Error, JSON::ParserError, AtlasRb::ResourceError
      false
    end

    def set_loader
      @loader = Loader.find_by(slug: params[:loader_slug])
      render template: 'errors/not_found', status: :not_found, layout: 'application' if @loader.nil?
    end

    def set_load_report
      @load_report = LoadReport.find_by(id: params[:id], loader: @loader)
      render template: 'errors/not_found', status: :not_found, layout: 'application' if @load_report.nil?
    end

    def require_loader_role
      return if current_user&.loader_tier?

      render template: 'errors/forbidden', status: :forbidden, layout: 'application'
    end

    def require_loader_group
      return if current_user&.admin?
      return if @loader && current_user&.groups&.include?(@loader.group)

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
