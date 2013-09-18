class Employee < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity

  attr_accessible :nuid, :name
  attr_protected :identifier

  after_create :generate_child_folders
  after_destroy :purge_personal_graph

  has_metadata name: 'details', type: DrsEmployeeDatastream

  belongs_to :parent, :property => :is_member_of, :class_name => 'Department'
  has_many :folders, :property => :is_member_of, :class_name => 'NuCollection' 

  def self.find_by_nuid(nuid) 
    query_result = ActiveFedora::SolrService.query("active_fedora_model_ssi:Employee AND nuid_tesim:'#{nuid}'", :rows=>999)
    Employee.find(query_result.first["id"])
  end

  def name=(string)
    self.details.name = string
  end

  def name
    self.details.name.first
  end

  def nuid=(string)
    self.details.nuid = string
  end

  def nuid
    self.details.nuid.first
  end

  def root_folder 
    return find_by_folder_type('user root')  
  end

  def research_publications 
    return find_by_folder_type('research publications')  
  end

  def other_publications 
    return find_by_folder_type('other publications') 
  end

  def data_sets 
    return find_by_folder_type('data sets') 
  end

  def presentations 
    return find_by_folder_type('presentations') 
  end

  def learning_objects
    return find_by_folder_type('learning objects') 
  end

  private 

    def find_by_folder_type(string) 
      return self.folders.find{ |f| f.personal_folder_type == string } 
    end

    def generate_child_folders
      Sufia.queue.push(GenerateUserFoldersJob.new(self.id, self.nuid, self.name))  
    end

    def purge_personal_graph
      self.root_folder.recursive_delete
    end
end