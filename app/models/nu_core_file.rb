class NuCoreFile < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity

  include Drs::ModelMethods
  include Drs::Noid
  include Drs::MetadataAssignment
  include Drs::Find
  include Drs::ImpressionCount

  include Drs::NuCoreFile::Actions
  include Drs::NuCoreFile::MimeTypes
  include Drs::NuCoreFile::Permissions
  include Drs::NuCoreFile::Characterization
  include Drs::NuCoreFile::Export
  include Drs::NuCoreFile::AssignType

  include Drs::Rights::MassPermissions
  include Drs::Rights::Embargoable
  include Drs::Rights::InheritedRestrictions
  include Drs::Rights::PermissionsAssignmentHelper

  include ModsDisplay::ModelExtension

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream
  has_metadata name: 'properties', type: DrsPropertiesDatastream
  has_metadata name: 'mods', type: NuModsDatastream

  attr_accessible :title, :non_sort, :identifier, :description, :date_of_issue
  attr_accessible :keywords, :creators, :depositor, :type

  before_destroy :purge_content_bearing_objects

  belongs_to :parent, :property => :is_member_of, :class_name => 'NuCollection'
  # call self.content_objects to get a list of all content bearing objects showing this
  # as their core record.

  delegate_to :mods, [:category, :department, :degree, :course_number, :course_title]

  has_many :other_parents,
            :property => :is_also_member_of,
            :class_name => "NuCollection"
  has_many :codebooks,
            :property => :is_codebook_for,
            :class_name => 'NuCoreFile'
  has_many :datasets,
            :property => :is_dataset_for,
            :class_name => 'NuCoreFile'
  has_many :figures,
            :property => :is_figure_for,
            :class_name => 'NuCoreFile'
  has_many :instructional_materials,
            :property => :is_instructional_material_for,
            :class_name => 'NuCoreFile'
  has_many :supplemental_materials,
            :property => :is_supplemental_material_for,
            :class_name => 'NuCoreFile'
  has_many :transcriptions,
            :property => :is_transcription_of,
            :class_name => 'NuCoreFile'

  has_and_belongs_to_many :also_member_of,
                            :property => :is_also_member_of,
                            :class_name => 'NuCollection'
  has_and_belongs_to_many :codebook_for,
                            :property => :is_codebook_for,
                            :class_name => 'NuCoreFile'
  has_and_belongs_to_many :dataset_for,
                            :property => :is_dataset_for,
                            :class_name => 'NuCoreFile'
  has_and_belongs_to_many :figure_for,
                            :property => :is_figure_for,
                            :class_name => 'NuCoreFile'
  has_and_belongs_to_many :instructional_material_for,
                            :property => :is_instructional_material_for,
                            :class_name => 'NuCoreFile'
  has_and_belongs_to_many :supplemental_material_for,
                            :property => :is_supplemental_material_for,
                            :class_name => 'NuCoreFile'
  has_and_belongs_to_many :transcription_of,
                            :property => :is_transcription_of,
                            :class_name => 'NuCoreFile'


  # The following two modifications are to account for the fact that
  # we're getting names unparsed in "lastName, firstName" from Fedora
  # on batch load. This parses that into seperate fields to match our
  # input form.

  mods_xml_source do |model|
    model.mods.to_xml
  end

  def to_solr(solr_doc = Hash.new())

    (0..self.mods.personal_name.length).each do |i|
      fn = self.mods.personal_name(i).name_part_given
      ln = self.mods.personal_name(i).name_part_family
      full_name = self.mods.personal_name(i).name_part

      if !full_name.blank? && full_name.first.length > 0
        name_array = Namae.parse full_name.first
        name_obj = name_array[0]
        if !name_obj.nil? && !name_obj.given.blank? && !name_obj.family.blank?
          self.mods.personal_name(i).name_part_given = name_obj.given
          self.mods.personal_name(i).name_part_family = name_obj.family
          self.mods.personal_name(i).name_part = ""

          # Pat introduced records with missing or bad depositor information
          # this ensures it doesn't crash a solr re-index
          begin
            self.save!
          rescue ActiveFedora::RecordInvalid => exception
            ExceptionNotifier.notify_exception(exception, :data => {:id => "#{self.pid}"})
          end
        end
      end
    end

    super(solr_doc)

    #Accounting for Pat's files coming in through the Fedora-direct harvest
    # If the file is of type with text, see if we can get solr to do a full text index
    if self.canonical_class.in?(['TextFile', 'MswordFile', 'PdfFile'])
      if self.canonical_object && self.canonical_object.datastreams.keys.include?("full_text")
        if self.canonical_object.full_text.content.nil?
          self.canonical_object.extract_content
        end
        solr_doc['all_text_timv'] = self.canonical_object.datastreams["full_text"].content
      end
    end

    return solr_doc
  end

  def pdf?
    self.class.pdf_mime_types.include? self.mime_type
  end

  def image?
    self.class.image_mime_types.include? self.mime_type
  end

  def video?
    self.class.video_mime_types.include? self.mime_type
  end

  def audio?
    self.class.audio_mime_types.include? self.mime_type
  end

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

  # Return a list of all in progress files associated with this nuid
  def self.in_progress_files_for_nuid(nuid)
    f_query = ActiveFedora::SolrService.query("depositor_tesim:\"#{nuid}\" AND in_progress_tesim:true")
    solr_list = f_query.map { |x| SolrDocument.new(x) }
    return solr_list.map { |x| NuCoreFile.find(x.pid) }
  end

  def in_progress_for_user?(user)
    return self.properties.in_progress? && user.nuid == self.depositor
  end

  # Returns an array of all abandoned files for this given depositor nuid
  def self.abandoned_for_nuid(nuid)
    as = ActiveFedora::SolrService

    nuid = "\"#{nuid}\""
    depositor = "depositor_tesim:#{nuid}"
    proxy_uploader = "proxy_uploader_tesim:#{nuid}"

    true_depositor_query = "(#{depositor} OR #{proxy_uploader})"
    f_query = as.query("#{true_depositor_query} AND in_progress_tesim:true")
    docs    = f_query.map { |x| SolrDocument.new (x) }
    now     = DateTime.now

    docs.keep_if do |doc|
      create_date     = doc.create_date_time
      (now - 15.minutes) > create_date
    end
  end

  def tag_as_completed
    self.properties.tag_as_completed
  end

  def tag_as_in_progress
    self.properties.tag_as_in_progress
  end

  def propagate_metadata_changes!
    content_objects.each do |content|
      content.rightsMetadata.content = self.rightsMetadata.content
      content.save!
    end
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
