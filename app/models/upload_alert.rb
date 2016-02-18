class UploadAlert < ActiveRecord::Base
  after_initialize :not_notified

  attr_accessible :depositor_email, :depositor_name, :title, :content_type, :editor_nuid
  attr_accessible :pid, :notified, :change_type, :collection_title, :collection_pid

  def self.withheld_research_publications(ct = :create)
    unknown_content_query('Research Publications', ct)
  end

  def self.withheld_theses(ct = :create)
    unknown_content_query('Theses and Dissertations', ct)
  end

  def self.withheld_datasets(ct = :create)
    unknown_content_query('Datasets', ct)
  end

  def self.withheld_technical_reports(ct = :create)
    unknown_content_query('Technical Reports', ct)
  end

  def self.withheld_learning_objects(ct = :create)
    unknown_content_query('Learning Objects', ct)
  end

  def self.withheld_presentations(ct = :create)
    unknown_content_query('Presentations', ct)
  end

  def self.withheld_other_pubs(ct = :create)
   unknown_content_query('Other Publications', ct)
  end

  def self.withheld_monographs(ct = :create)
    unknown_content_query('Monographs', ct)
  end

  def self.withheld_nonfeatured(ct = :create)
    unknown_content_query("", ct)
  end

  def self.withheld_collections(ct = :create)
    unknown_content_query('collection', ct)
  end

  def self.create_from_core_file(core_file, change_type, current_user=nil)
    if !([:update, :create].include? change_type)
      raise %Q(Passed #{change_type.class} #{change_type} to create_from_core_file,
               which takes either symbol :update or :create)
    end

    u = UploadAlert.new
    user = User.find_by_nuid(core_file.true_depositor)

    if !user.nil?
      u.depositor_email   = user.email
      u.depositor_name    = user.full_name
    else
      # try to find the emp obj - iris migrated objects most likely
      emp = Employee.find_by_nuid(core_file.true_depositor)
      u.depositor_name    = emp.name
      u.depositor_email   = ""
    end

    u.title             = core_file.title
    u.content_type      = core_file.category.first
    u.pid               = core_file.pid
    u.change_type       = change_type
    u.collection_pid    = core_file.parent.pid
    u.collection_title  = core_file.parent.title
    if !current_user.nil?
      u.editor_nuid       = current_user.nuid
    end
    u.save! ? u : false
  end

  def self.create_from_collection(collection, change_type, current_user=nil)
    if !([:update, :create].include? change_type)
      raise %Q(Passed #{change_type.class} #{change_type} to create_from_collection,
               which takes either symbol :update or :create)
    end

    u = UploadAlert.new
    user = User.find_by_nuid(collection.true_depositor)

    if !user.nil?
      u.depositor_email   = user.email
      u.depositor_name    = user.full_name
    end

    u.title             = collection.title
    u.content_type      = "collection"
    u.pid               = collection.pid
    u.change_type       = change_type
    u.collection_pid    = collection.parent.pid
    u.collection_title  = collection.parent.title
    if !current_user.nil?
      u.editor_nuid       = current_user.nuid
    end
    u.save! ? u : false
  end

  private
    def not_notified
      self.notified = false if self.notified.nil?
    end

    def self.unknown_content_query(content_type, change_type)
      q = 'content_type = ? AND change_type = ? AND notified = ?'
      UploadAlert.where(q, content_type, change_type, false).find_all
    end
end
