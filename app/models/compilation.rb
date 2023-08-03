class Compilation < ActiveFedora::Base
  include ApplicationHelper
  include Hydra::ModelMethods
  include Hydra::ModelMixins::RightsMetadata
  include ActiveModel::MassAssignmentSecurity
  include Cerberus::MetadataAssignment
  include Cerberus::Find
  include Cerberus::Persist
  include Cerberus::Rights::MassPermissions
  include Cerberus::Rights::PermissionsAssignmentHelper

  has_metadata name: 'DC', type: DublinCoreDatastream
  has_metadata name: 'mods', type: ModsDatastream
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: PropertiesDatastream

  attr_accessible :title, :identifier, :depositor, :description

  has_many :entries, class_name: "CoreFile, Collection",  property: :has_member

  def entries
    @set = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{self.id}\"").first)
    return @set.entries
  end

  # Returns the pids of all objects tagged as entries
  # in this collection.
  def entry_ids
    a = self.relationships(:has_member)
    return a.map{ |rels| rels.split('/').last }
  end

  def add_entry(value)
    if value.instance_of?(CoreFile)
      if !check_for_duplicates(value)
        add_relationship(:has_member, value)
        true
      else
        false
      end
    elsif value.instance_of?(Collection)
      if !check_for_duplicates(value)
        add_relationship(:has_member, value)
        true
      else
        false
      end
    elsif value.instance_of?(String)
      obj = ActiveFedora::SolrService.query("id:\"#{value}\"")
      doc = SolrDocument.new(obj.first)
      if doc.klass == "CoreFile"
        object = CoreFile.find(value)
        if !check_for_duplicates(object)
          add_relationship(:has_member, object)
          true
        else
          false
        end
      elsif doc.klass == "Collection"
        object = Collection.find(value)
        if !check_for_duplicates(object)
          add_relationship(:has_member, object)
          true
        else
          false
        end
      end
    else
      false
    end
  end

  def remove_entry(value)
    if value.instance_of?(CoreFile) || value.instance_of?(Collection)
      remove_relationship(:has_member, value)
    elsif value.instance_of?(String)
      remove_relationship(:has_member, "info:fedora/#{value}")
    end
  end

  # Adds a simple JSON api to use with the JavaScript a bit easier than before
  def as_json(opts = nil)
    { id: self.pid,
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
      elsif entry.instance_of?(String)
        obj = ActiveFedora::SolrService.query("id:\"#{entry}\"")
        doc = SolrDocument.new(obj.first)
        if doc.tombstoned?
          results << entry
          remove_entry(entry)
        end
      end
    end

    self.save!
    return results
  end

  def check_for_duplicates(object)
    if !self.entry_ids.include?(object.pid)
      all = []
      self.entry_ids.each do |e|
        if e.instance_of?(String)
          doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{e}\"").first)
          if doc.klass == 'CoreFile'
            all << doc.pid
          elsif doc.klass == 'Collection'
            children = doc.all_descendent_files
            children.each do |c|
              all << c.pid
            end
          end
        elsif e.instance_of?(CoreFile)
          all << e.pid
        elsif e.instance_of?(Collection)
          children = doc.all_descendent_files
          children.each do |c|
            all << c.pid
          end
        end
      end
      if all.include?(object) || all.include?(object.pid)
        true
      else
        false
      end
    else
      false
    end
  end

  def object_ids
    docs = []
    self.entries.each do |e|
      if e.klass == 'CoreFile'
        docs << e.pid
      else
        docs << e.pid
        e.all_descendent_files.each do |f|
          docs << f.pid
        end
      end
    end
    # docs.select! { |doc| current_user.can?(:read, doc) }
    docs
  end

  private

    # Takes a string of form "info:fedora/neu:abc123"
    # and returns just the pid
    def trim_to_pid(string)
      return string.split('/').last
    end
end
