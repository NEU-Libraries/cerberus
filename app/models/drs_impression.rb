class DrsImpression < ActiveRecord::Base 
  attr_accessible :pid, :session_id, :action
  validates_uniqueness_of :session_id, :scope => [:pid, :action]
end