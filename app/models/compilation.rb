class Compilation < ActiveFedora::Base
  include Hydra::ModelMethods
  include Hydra::ModelMixins::RightsMetadata
  include ActiveModel::MassAssignmentSecurity
  include Cerberus::MetadataAssignment
  include Cerberus::Find
  include Cerberus::Rights::MassPermissions
  include Cerberus::Rights::PermissionsAssignmentHelper

  has_metadata name: 'DC', type: DublinCoreDatastream
  has_metadata name: 'mods', type: ModsDatastream
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: PropertiesDatastream

  attr_accessible :title, :identifier, :depositor, :description

  has_many :entries, class_name: "CoreFile",  property: :has_member

  def self.users_compilations(user)
    Compilation.find(:all).keep_if { |file| file.depositor == user.nuid }
  end

  # Returns the pids of all objects tagged as entries
  # in this collection.
  def entry_ids
    a = self.relationships(:has_member)
    return a.map{ |rels| trim_to_pid(rels) }
  end

  # Returns all CoreFile objects tagged as entries
  # in this collection as SolrDocument objects.
  def entries
    if entry_ids.any?
      query = ""
      query = self.entry_ids.map! { |id| "\"#{id}\""}.join(" OR ")
      query = "id:(#{query})"

      solr_query(query)
    else
      []
    end
  end

  def add_entry(value)
    if value.instance_of?(CoreFile)
      add_relationship(:has_member, value)
    elsif value.instance_of?(String)
      object = CoreFile.find(value)
      add_relationship(:has_member, object)
    else
      raise "Add item can only take a string or an instance of a Core object"
    end
  end

  def remove_entry(value)
    if value.instance_of?(CoreFile)
      remove_relationship(:has_member, value)
    elsif value.instance_of?(String)
      remove_relationship(:has_member, "info:fedora/#{value}")
    end
  end

  # Adds a simple JSON api to use with the JavaScript a bit easier than before
  def as_json(opts = nil)
    { id: self.identifier,
      title: self.title,
      depositor: self.depositor,
      description:  self.description,
      entries: self.entry_ids,
      mass_permissions: self.mass_permissions }
  end

  # Eliminate every entry ID that points to an object that no longer exists
  # Return the pid of each entry removed.
  # Behavior of this method is weirdly flaky in the case where self is held in memory
  # /while/ the CoreFile is deleted.
  # If you've having problems that appear to be caused by self.relationships(:has_member)
  # returning "info:fedora/" try reloading the object you're holding before executing this.
  def remove_dead_entries
    results = []

    self.entry_ids.each do |entry|
      if !ActiveFedora::Base.exists?(entry)
        results << entry
        remove_entry(entry)
      end
    end

    self.save!
    return results
  end

  private

    # Takes a string of form "info:fedora/neu:abc123"
    # and returns just the pid
    def trim_to_pid(string)
      return string.split('/').last
    end

    def solr_query(query_string)
      # By default, SolrService.query only returns 10 rows
      # You can specify more rows than you need, but not just to return all results
      # This is a small helper method that combines SolrService's count and query to
      # get back all results, without guessing at an upper limit
      row_count = ActiveFedora::SolrService.count(query_string)
      query_result = ActiveFedora::SolrService.query(query_string, :rows => row_count)
      return query_result.map { |x| SolrDocument.new(x) }
    end
end
