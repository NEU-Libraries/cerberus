class DownloadsController < ApplicationController
  include Drs::DownloadsControllerBehavior
  include Drs::ControllerHelpers::ViewLogger

  after_filter :log_download, only: [:show]
end
