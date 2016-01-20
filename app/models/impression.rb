class Impression < ActiveRecord::Base
  attr_accessible :pid, :session_id, :action, :ip_address, :referrer, :status, :user_agent, :public, :processed

  # Ensure that all required fields are present
  validates :pid, :session_id, :action, :ip_address, presence: true
  validates :referrer, :status, :user_agent, presence: true

  # Changing to a check if ip, pid, action have been done in the last hour
  # session lasts until deployment - lowering stats in a hamfisted way
  validate :throttle_creation, on: :create

  def throttle_creation
    # We implement this to prevent outliers - bots that we're unaware of,
    # hyperactive refreshing of a page etc.
    results = Impression.where("pid = ? AND action = ? AND ip_address = ?", self.pid, self.action, self.ip_address)
    if results.count > 0
      last_hour = false

      results.each do |result|
        if result.created_at > 1.hour.ago
          last_hour = true
        end
      end

      if last_hour
        errors.add(:ip_address, "This action for this pid was done by #{self.ip_address} within the last hour")
      end
    end
  end
end
