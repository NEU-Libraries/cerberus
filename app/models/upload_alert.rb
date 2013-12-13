class UploadAlert < ActiveRecord::Base
  after_initialize :not_notified

  attr_accessible :depositor_email, :depositor_name, :title, :content_type
  attr_accessible :pid, :notified, :change_type

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

  def self.create_from_core_file(core_file, change_type) 
    if !([:edit, :create].include? change_type)
      raise %Q(Passed #{change_type.class} #{change_type} to create_from_core_file, 
               which takes either symbol :edit or :create)
    end

    u = UploadAlert.new 
    user = User.find_by_nuid(core_file.depositor) 

    u.depositor_email = user.email 
    u.depositor_name  = user.full_name 
    u.title           = core_file.title 
    u.content_type    = core_file.category.first
    u.pid             = core_file.pid 
    u.change_type     = change_type 
    u.save! ? u : false
  end 

  private 
    def not_notified 
      self.notified = false if self.notified.nil?
    end

    def self.unknown_content_query(content_type)
      UploadAlert.where('content_type = ? AND notified = ?', content_type, false).find_all
    end 
end