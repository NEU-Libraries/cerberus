class DownloadsController < ApplicationController
  include Drs::DownloadsControllerBehavior
  include Drs::ControllerHelpers::ViewLogger

  # Ensure that only downloads of content datastreams are triggering this.
  # Without this check displaying thumbnails and video poster images will also
  # trigger downloads.  This assumes that significant, actually downloadable
  # items will always be stored in a datastream called 'content' on some object
  after_filter(only: [:show]) do |c|
    if params[:datastream_id] == 'content'
      c.log_action('download', 'COMPLETE')
    end
  end

  rescue_from ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Object"

    if !current_user.nil?
      email_handled_exception(exception)
    end

    render_404(ActiveFedora::ObjectNotFoundError.new) and return
  end
end
