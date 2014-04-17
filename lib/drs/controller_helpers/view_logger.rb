# Module for doing very simple impression logging.
# Uses session hash to determine uniqueness, only writes unique views.

module Drs::ControllerHelpers::ViewLogger

  def log_view
    log_action('view')
  end

  def log_download
    # Ensure that only downloads of content datastreams are triggering this.
    # Without this check displaying thumbnails and video poster images will also
    # trigger downloads.  This assumes that significant, actually downloadable
    # items will always be stored in a datastream called 'content' on some object
    if params[:datastream_id] == 'content'
      log_action('download')
    end
  end

  private

    def log_action(action)
      id = params[:id]
      session = request.session_options[:id]
      ip = request.remote_ip

      DrsImpression.create(pid: id, session_id: session, action: action, ip_address: ip)
    end
end
