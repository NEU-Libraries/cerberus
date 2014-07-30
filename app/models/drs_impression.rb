class DrsImpression < ActiveRecord::Base
  attr_accessible :pid, :session_id, :action, :ip_address, :referrer, :status

  # Ensure that all required fields are present
  validates :pid, :session_id, :action, :ip_address, presence: true
  validates :referrer, :status, presence: true

  # Store all IP addresses the first time they read or download an item
  validates_uniqueness_of :session_id, :scope => [:pid, :action]
end
