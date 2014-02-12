# Module for doing very simple impression logging. 
# Uses session hash to determine uniqueness, only writes unique views. 

module Drs::ControllerHelpers::ViewLogger 
  def view_logger
    id = params[:id] 
    session = request.session_options[:id] 

    DrsImpression.create(pid: id, session_id: session)
  end
end