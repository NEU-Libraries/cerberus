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
    escaped_param = ActiveFedora::SolrService.escape_uri_for_query(nuid)
    query_result = ActiveFedora::SolrService.query("active_fedora_model_ssi:Employee AND nuid_tesim:(#{escaped_param})", :rows=>999)
    if query_result.length == 0 
      raise NoSuchNuidError.new(nuid)
    elsif query_result.length > 1 
      all_pids = query_result.map { |r| r["id"] } 
      raise MultipleMatchError.new(all_pids, nuid) 
    else
      Employee.find(query_result.first["id"])
    end
   end

   def self.exists_by_nuid?(nuid) 
    begin 
      self.find_by_nuid(nuid)
      return true  
    rescue Employee::NoSuchNuidError 
      return false 
    end
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

  def sorted_folders 
    return [research_publications, other_publications, data_sets, presentations, learning_objects] 
  end

  def personal_folders 
    return self.folders.select { |f| f.personal_folder_type == 'miscellany' && f.parent.pid == self.root_folder.pid } 
  end

  private 

    def find_by_folder_type(string) 
      return self.folders.find{ |f| f.personal_folder_type == string } 
    end

    def generate_child_folders
      Sufia.queue.push(GenerateUserFoldersJob.new(self.id, self.nuid, self.name))  
    end

    def purge_personal_graph
      self.root_folder.recursive_delete if !self.folders.empty?
    end

    class NoSuchNuidError < StandardError
      attr_accessor :nuid 
      def initialize(nuid)
        self.nuid = nuid 
        super("No Employee object with nuid #{self.nuid} could be found in the graph.") 
      end
    end

    class MultipleMatchError < StandardError 
      attr_accessor :arry, :nuid 
      def initialize(array_of_pids, nuid) 
        self.arry = array_of_pids 
        self.nuid = nuid 
        super("The following Employees all have nuid = #{self.nuid} (that's bad): #{arry}")
      end
    end
end