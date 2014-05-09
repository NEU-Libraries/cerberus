class NuCoreFile < ActiveFedora::Base
  #include Sufia::GenericFile
  include Drs::NuCoreFile::AccessibleAttributes
  include Drs::Rights::MassPermissions
  include Drs::Rights::Embargoable
  include Drs::Rights::InheritedRestrictions
  include Drs::Rights::PermissionsAssignmentHelper
  include Drs::MetadataAssignment
  include Drs::NuCoreFile::Export
  include Drs::NuCoreFile::AssignType
  include Drs::Find
  include Drs::ImpressionCount

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream
  has_metadata name: 'properties', type: DrsPropertiesDatastream
  has_metadata name: 'mods', type: NuModsDatastream

  attr_accessible :title, :identifier, :description, :date_of_issue
  attr_accessible :keywords, :creators, :depositor, :type

  before_destroy :purge_content_bearing_objects

  belongs_to :parent, :property => :is_member_of, :class_name => 'NuCollection'
  # call self.content_objects to get a list of all content bearing objects showing this
  # as their core record.

  delegate_to :mods, [:category, :department, :degree, :course_number, :course_title]

  delegate_to :descMetadata, [:rights, :resource_type]

  def to_param
    self.pid
  end

  # Safely set the parent of a collection.
  def set_parent(collection, user)
    if user.can? :edit, collection
      self.parent = collection
      self.properties.parent_id = collection.pid
      return true
    else
      raise "User with nuid #{user.nuid} cannot add items to collection with pid of #{collection.pid}"
    end
  end

  # Return a list of all in progress files associated with this user
  def self.users_in_progress_files(user)
    all = NuCoreFile.find(:all)
    filtered = all.keep_if { |file| file.in_progress_for_user?(user) }
    return filtered
  end

  def in_progress_for_user?(user)
    return self.properties.in_progress? && user.nuid == self.depositor
  end

  def tag_as_completed
    self.properties.tag_as_completed
  end

  def tag_as_in_progress
    self.properties.tag_as_in_progress
  end

  def persistent_url
    "#{Rails.configuration.persistent_hostpath}#{pid}"
  end

  def content_objects
    all_possible_models = [ "ImageSmallFile", "ImageMediumFile", "ImageLargeFile",
                            "ImageMasterFile", "ImageThumbnailFile", "MsexcelFile",
                            "MspowerpointFile", "MswordFile", "PdfFile", "TextFile",
                            "ZipFile", "AudioFile", "VideoFile" ]
    models_stringified = all_possible_models.inject { |base, str| base + " or #{str}" }
    models_query = ActiveFedora::SolrService.escape_uri_for_query models_stringified
    full_self_id = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{self.pid}"

    query_result = ActiveFedora::SolrService.query("active_fedora_model_ssi:(#{models_stringified}) AND is_part_of_ssim:#{full_self_id}", rows: 999)

    return assigned_lookup(query_result)
  end

  # Find the canonical record for this object.
  # Raise a warning if none or more than one exist.
  def canonical_object
    c = self.content_objects.count { |c| c.canonical? }
    if c != 1
      Rails.logger.warn "#{pid} is returning #{c} content objects. It should have one."
    end

    self.content_objects.find { |c| c.canonical? } || false
  end

  # Find the ImageThumbnail for this object
  # Raise a warning if more than one exists.
  def thumbnail
    c = self.content_objects.count { |c| c.instance_of? ImageThumbnailFile }
    if c > 1
      Rails.logger.warn "#{self.pid} is returning #{c} thumbnails.  It ought to have one or zero"
    end

    self.content_objects.find { |c| c.instance_of? ImageThumbnailFile } || false
  end

  def type_label
    "File"
  end

  private

    def purge_content_bearing_objects
      self.content_objects.each do |e|
        e.destroy
      end
    end

    def assigned_lookup(solr_query_result)
      return solr_query_result.map { |r| r["active_fedora_model_ssi"].constantize.find(r["id"]) }
    end
end
