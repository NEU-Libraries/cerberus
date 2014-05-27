class DownloadsController < ApplicationController
  include Drs::DownloadsControllerBehavior
  include Drs::ControllerHelpers::ViewLogger

  after_filter :log_download, only: [:show]

  rescue_from ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Object"
    ExceptionNotifier.notify_exception(exception)
    render_404(ActiveFedora::ObjectNotFoundError.new) and return
  end
end
