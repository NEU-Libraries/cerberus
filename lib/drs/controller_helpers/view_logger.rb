# Module for doing very simple impression logging. 
# Uses session hash to determine uniqueness, only writes unique views. 

module Drs::ControllerHelpers::ViewLogger 

  def log_view 
    log_action('view') 
  end

  def log_download 
    log_action('download') 
  end

  private 

    def log_action(action)
      id = params[:id] 
      session = request.session_options[:id] 

      DrsImpression.create(pid: id, session_id: session, action: action) 
    end
end