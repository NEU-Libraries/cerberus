# Module for doing very simple impression logging.
# Uses session hash to determine uniqueness, only writes unique views.
module Cerberus::ControllerHelpers::ViewLogger

  def log_action(action, status, id = nil)
    id ||= params[:id]

    session = request.session_options[:id]
    ip = request.remote_ip

    if request.referrer.blank?
      ref = "direct"
    else
      ref = request.referrer
    end

    u_a = request.user_agent

    Impression.create(pid: id, session_id: session, action: action, ip_address: ip,
                          referrer: ref, user_agent: u_a, status: status)
  end
end
