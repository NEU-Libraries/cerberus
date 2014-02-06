class DrsImpression < ActiveRecord::Base 
  validates_uniqueness_of :session_id, :scope => :pid
end