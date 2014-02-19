class DownloadsController < ApplicationController 
  include Sufia::DownloadsControllerBehavior
  include Drs::ControllerHelpers::ViewLogger 

  after_filter :log_download, only: [:show]
end