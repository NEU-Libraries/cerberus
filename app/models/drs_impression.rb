class DrsImpression < ActiveRecord::Base 
  attr_accessible :pid, :session_id
  validates_uniqueness_of :session_id, :scope => :pid
end