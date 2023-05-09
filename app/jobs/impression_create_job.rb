class ImpressionCreateJob

  attr_accessor :pid, :session_id, :action, :ip_address, :referrer, :user_agent, :status

  def initialize(pid, session_id, action, ip_address, referrer, user_agent, status)
    self.pid = pid
    self.session_id = session_id
    self.action = action
    self.ip_address = ip_address
    self.referrer = referrer
    self.user_agent = user_agent
    self.status = status
  end

  def queue_name
    :impression_create
  end

  def run
    begin
      retries ||= 0
      Impression.create(pid: pid, session_id: session_id, action: action, ip_address: ip_address,
        referrer: referrer, user_agent: user_agent, status: status)
    rescue Mysql2::Error
      retry if (retries += 1) < 3
    end
  end
end
