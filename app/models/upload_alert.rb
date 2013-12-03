class UploadAlert < ActiveRecord::Base
  after_initialize :not_notified
  attr_accessible :depositor_email, :depositor_name, :title, :type, :pid, :notified

  def self.withheld_research_publications
    unknown_content_query('research publications') 
  end

  def self.withheld_theses
    unknown_content_query('theses')
  end

  def self.withheld_datasets
    unknown_content_query('datasets') 
  end

  def self.withheld_learning_objects
    unknown_content_query('learning objects') 
  end

  def self.withheld_presentations
    unknown_content_query('presentations') 
  end

  private 
    def not_notified 
      self.notified = false if self.notified.nil?
    end

    def self.unknown_content_query(content_type)
      UploadAlert.where('content_type = ? AND notified = ?', content_type, false).find_all
    end 
end