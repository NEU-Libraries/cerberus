module Drs
  module NuFile
    extend ActiveSupport::Concern
    include ActiveModel::MassAssignmentSecurity
    include Hydra::ModelMethods
    include Hydra::ModelMixins::RightsMetadata
    include Drs::MetadataAssignment
    include Drs::Rights::MassPermissions
    include Drs::NuFile::Characterizable
    include Hydra::Derivatives 

    included do
      attr_accessible :title, :description, :keywords, :identifier
      attr_accessible :depositor, :date_of_issue, :core_record 
      attr_accessible :creators

      has_metadata name: 'DC', type: NortheasternDublinCoreDatastream 
      has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
      has_metadata name: 'properties', type: DrsPropertiesDatastream
      has_file_datastream name: "content", type: FileContentDatastream
      
      belongs_to :core_record, property: :is_part_of, class_name: 'NuCoreFile'
    end

    def self.create_master_content_object(core_file, file, datastream_id, user)
      if NuFile.virus_check(file) != 0 
        raise "#{file.original_filename} cannot be processed" 
      end

      content_object = NuFile.instantiate_appropriate_content_object(file)

      content_object.add_file(file, datastream_id, file.original_filename) 
      content_object.core_record =  core_file
      content_object.title       =  file.original_filename 
      content_object.identifier  =  content_object.pid
      content_object.depositor   =  user.nuid
      content_object.canonize

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
          return ImageMasterFile.new(pid: pid)
        elsif mime.raw_sub_type == 'pdf' 
          return PdfFile.new(pid: pid) 
        elsif mime.raw_sub_type == 'xml+xslt' 
          return XmlXsltFile.new(pid: pid)
        elsif mime.raw_sub_type == 'xml'
          return XmlEadFile.new(pid: pid)
        elsif Drs::NuFile.matches_msword?(file_name)
          return MsWordFile.new(pid: pid)
        elsif Drs::NuFile.matches_msexcel?(file_name) 
          return MsExceltFile.new(pid: pid)
        elsif Drs::NuFile.matches_msppt?(file_name) 
          return MspowerpointFile.new(pid: pid) 
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
end