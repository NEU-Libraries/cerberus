class Employee < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity
  include ActiveModel::Validations
  include Drs::Employee::FacultyFolders

  attr_accessible :nuid, :name, :department
  attr_accessor   :building
  attr_protected  :identifier

  validate :nuid_unique, on: :create

  has_metadata name: 'details', type: DrsEmployeeDatastream

  belongs_to :parent, :property => :has_affiliation, :class_name => 'Department'
  has_many :folders, :property => :is_member_of, :class_name => 'NuCollection'

  def department=(department_id)
    self.add_relationship(:has_affiliation, department_id) 
  end 

  def self.find_by_nuid(nuid) 
    escaped_param = ActiveFedora::SolrService.escape_uri_for_query(nuid)
    query_result = ActiveFedora::SolrService.query("active_fedora_model_ssi:Employee AND nuid_tesim:(#{escaped_param})", :rows=>999)
    if query_result.length == 0 
      raise NoSuchNuidError.new(nuid)
    elsif query_result.length > 1 
      all_pids = query_result.map { |r| r["id"] } 
      raise MultipleMatchError.new(all_pids, nuid) 
    else
      Employee.safe_employee_lookup(query_result.first["id"]) 
    end
   end

   def self.exists_by_nuid?(nuid) 
    Employee.all.each do |e| 
      if e.nuid == nuid 
        return true 
      end
    end

    return false 
  end

  def building=(val) 
    self.employee_is_building if val 
  end

  def employee_is_building
    self.details.employee_is_building 
  end

  def employee_is_complete
    self.details.employee_is_complete 
  end

  def is_building?
    self.details.is_building? 
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

  private

    def self.safe_employee_lookup(id, retries=0)
      lookup = Employee.find(id)
      if !lookup.is_building?
        return lookup 
      elsif retries < 3
        puts "retry #{retries}"
        sleep 3
        safe_employee_lookup(id, retries + 1) 
      else
        raise EmployeeWontStopBuildingError.new(id)
      end
    end

    def generate_child_folders
      fresh_lookup = Employee.find_by_nuid(self.nuid)
      if fresh_lookup.folders.empty?
        Sufia.queue.push(GenerateUserFoldersJob.new(self.id, self.nuid, self.name))
      end  
    end

    def nuid_unique 
      if Employee.exists_by_nuid? self.nuid 
        errors.add(:nuid, "#{self.nuid} is already in use as an Employee object NUID")   
      end
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

    class EmployeeWontStopBuildingError < StandardError 
      attr_accessor :nuid 
      def initialize(nuid) 
        self.nuid = nuid
        super("Employee object with nuid #{self.nuid} seems to be stuck in progress.") 
      end
    end
end