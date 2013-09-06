module NuFile
  extend ActiveSupport::Concern
  include Hydra::ModelMethods

  included do
  	has_metadata name: 'DC', type: NortheasternDublinCoreDatastream 
  	has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
    has_file_datastream :name => "content", :type => FileContentDatastream
    
    belongs_to :nu_core_file, :property => :is_part_of, :class_name => 'NuCoreFile'

    delegate_to :DC, [:nu_title, :nu_description, :nu_identifier]
  end

  def title=(value)
    self.DC.nu_title = value 
  end

  def title 
    self.DC.nu_title.first 
  end

  def description=(value)
    self.DC.nu_description = value 
  end

  def description 
    self.DC.nu_description.first 
  end

  def identifier=(value) 
    self.DC.nu_identifier = value 
  end

  def identifier
    self.DC.nu_identifier.first 
  end

  def self.create_master_content_object(core_file, file, datastream_id, user)
    if NuFile.virus_check(file) != 0 
      raise "#{file.original_filename} cannot be processed" 
    end

    content_object = NuFile.instantiate_appropriate_content_object(file)

    content_object.add_file(file, datastream_id, file.original_filename) 
    content_object.add_relationship(:is_part_of, core_file)
    content_object.nu_title = file.original_filename 
    content_object.nu_identifier = content_object.pid
    content_object.rightsMetadata.permissions({person: user.nuid}, 'edit')

    begin
      content_object.save!
    rescue RSolr::Error::Http => error
      logger.warn "GenericFilesController::create_and_save_generic_file Caught RSOLR error #{error.inspect}"
      save_tries+=1
      # fail for good if the tries is greater than 3
      raise error if save_tries >=3
      sleep 0.01
      retry
    end

    puts "Content object PID is #{content_object.pid}" 
  end

  def self.virus_check(file)
    if defined? ClamAV
      stat = ClamAV.instance.scanfile(file.path)
      logger.warn "Virus checking did not pass for #{file.inspect} status = #{stat}" unless stat == 0
      stat
    else
      logger.warn "Virus checking disabled for #{file.inspect}"
      0
    end
  end

  private

    def self.instantiate_appropriate_content_object(file)

      file_name = file.original_filename 

      if MIME::Types.of(file_name).length == 0
        raise "#{file.original_filename} does not appear to have a MIME type."
      end 

      mime = MIME::Types.of(file_name).first
      pid = Sufia::Noid.namespaceize(Sufia::IdService.mint)


      if mime.raw_media_type == 'image' 
        return ContentTypes::ImageMasterFile.new(pid: pid)
      elsif mime.raw_sub_type == 'pdf' 
        return ContentTypes::PdfFile.new(pid: pid) 
      elsif mime.raw_sub_type == 'xml+xslt' 
        return ContentTypes::XmlXsltFile.new(pid: pid)
      elsif mime.raw_sub_type == 'xml'
        return ContentTypes::XmlEadFile.new(pid: pid)
      elsif NuFile.matches_msword?(file_name)
        return ContentTypes::MsWordFile.new(pid: pid)
      elsif NuFile.matches_msexcel?(file_name) 
        return ContentTypes::MsExceltFile.new(pid: pid)
      elsif NuFile.matches_msppt?(file_name) 
        return ContentTypes::MspowerpointFile.new(pid: pid) 
      else
        raise "#{file.original_filename} cannot be processed." 
      end   
    end

    def self.matches_msexcel?(filename)
      matches = ['xls', 'xlt', 'xla', 'xlsx', 'xltx', 'xlsm', 'xltm', 'xlam']

      return self.match_extension(filename, matches)
    end

    def self.matches_msword?(filename) 
      matches = ['doc', 'dot', 'docx', 'dotx', 'docm', 'dotm'] 

      return self.match_extension(filename, matches)
    end

    def self.matches_msppt?(filename) 
      matches = ['ppt', 'pot', 'pps', 'ppa', 'pptx', 'potx', 'ppsx', 'ppam',
                 'pptm', 'potm', 'ppsm'] 

      return self.match_extension(filename, matches) 
    end

    def self.match_extension(filename, matches) 
      extension = filename.split(".").last 

      return matches.include?(extension) 
    end
end