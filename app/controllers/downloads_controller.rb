class DownloadsController < ApplicationController
  include Cerberus::DownloadsControllerBehavior
  include Cerberus::ControllerHelpers::ViewLogger

  before_filter :ensure_not_embargoed, :only => :show

  # Ensure that only downloads of content datastreams are triggering this.
  # Without this check displaying thumbnails and video poster images will also
  # trigger downloads.  This assumes that significant, actually downloadable
  # items will always be stored in a datastream called 'content' on some object
  after_filter(only: [:show]) do |c|
    if params[:datastream_id] == 'content'
      c.log_action('download', 'COMPLETE')
    end
  end

  rescue_from ArgumentError do |exception|
    # This is error spam from scripts that haven't figured out that hitting urls
    # like https://repository.library.northeastern.edu/downloads/neu:180772 doesn't
    # work - do nothing
    render :nothing => true, :status => 500, :content_type => 'text/html' and return
  end

  rescue_from ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Object"

    if !current_user.nil?
      email_handled_exception(exception)
    end

    render_404(ActiveFedora::ObjectNotFoundError.new, request.fullpath) and return
  end

  rescue_from Hydra::AccessDenied, CanCan::AccessDenied do |exception|
    flash[:error] = exception.message

    if !current_user.nil?
      email_handled_exception(exception)
    end

    render_403 and return
  end

  def show
    # 301 redirect fulltext if not logged in to try and boost google scholar
    if current_user.nil?
      # Tombstoned files will return a nil core_record
      if asset.class == PdfFile && !asset.core_record.blank?
        doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{asset.core_record.pid}\"").first
        if doc.public?
          if doc.category == "Theses and Dissertations" || doc.category == "Technical Reports" || doc.category == "Research Publications"
            if !doc.canonical_object.first.embargo_date_in_effect?
              redirect_to file_fulltext_path(doc.pid), :status => 301 and return
            end
          end
        end
      end
    elsif asset.class == ImageThumbnailFile && (Rails.env.staging? || Rails.env.production?)
      response.headers['Cache-Control'] = "public"
    end
    super
  end

  private
    def ensure_not_embargoed
      dl = fetch_solr_document

      # Should always show thumbnails no matter what
      return true if dl.klass == "ImageThumbnailFile"

      if dl.is_content_object?
        core = dl.get_core_record
        raise ActiveFedora::ObjectNotFoundError if core.under_embargo?(current_user)
      else
        raise ActiveFedora::ObjectNotFoundError if dl.under_embargo?(current_user)
      end
    end
end
