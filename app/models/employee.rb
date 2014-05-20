class Employee < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity
  include ActiveModel::Validations
  include Drs::Employee::SmartCollections
  include Drs::Find
  include Drs::Rights::MassPermissions

  attr_accessible :nuid, :name, :community
  attr_accessor   :building
  attr_protected  :identifier

  validate :nuid_unique, on: :create

  before_save :add_community_names

  has_metadata name: 'details', type: DrsEmployeeDatastream
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream

  belongs_to :parent, :property => :has_affiliation, :class_name => 'Community'
  has_many :smart_collections, :property => :is_member_of, :class_name => 'NuCollection'

  def add_community(c_id)
    self.add_relationship(:has_affiliation, c_id)
  end

  def remove_community(c_id)
    self.remove_relationship(:has_affiliation, c_id)
  end

  # Return an array of Community Objects
  # That this employee is associated with.
  def communities
    result = []
    self.relationships(:has_affiliation).each do |rel|
      result << Community.find(rel[12..-1])
    end
    return result
  end

  def self.find_by_nuid(nuid)
    results = nuid_unique_query(nuid)

    if results.length != 0
      Employee.safe_employee_lookup(results.first["id"])
    end
  end

  def self.exists_by_nuid?(nuid)
    results = nuid_unique_query(nuid)
    !results.empty?
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

    def add_community_names
      community_names = self.communities.map { |x| x.title }
      details.community_name = community_names
    end

    def self.safe_employee_lookup(id, retries=0)
      lookup = Employee.find(id)
      if !lookup.is_building?
        return lookup
      elsif retries < 3
        puts "retry #{retries}"
        sleep 3
        safe_employee_lookup(id, retries + 1)
      else
        raise Exceptions::EmployeeWontStopBuildingError.new(id)
      end
    end

    # Query Solr for the given nuid.
    # Raise an error if multiple hits are returned
    def self.nuid_unique_query(nuid)
      escaped_param = ActiveFedora::SolrService.escape_uri_for_query(nuid)
      query_result = ActiveFedora::SolrService.query("active_fedora_model_ssi:Employee AND nuid_tesim:(#{escaped_param})", :rows=>999)

      if query_result.length > 1
        all_pids = query_result.map { |r| r["id"] }
        raise Exceptions::MultipleMatchError.new(all_pids, nuid)
      else
        return query_result
      end
    end

    def nuid_unique
      if Employee.exists_by_nuid? self.nuid
        errors.add(:nuid, "#{self.nuid} is already in use as an Employee object NUID")
      end
    end
end
