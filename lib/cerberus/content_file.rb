module Cerberus
  module ContentFile
    extend ActiveSupport::Concern
    include ActiveModel::MassAssignmentSecurity
    include Hydra::ModelMethods
    include Hydra::Derivatives
    include Hydra::ModelMixins::RightsMetadata    
    include Cerberus::MetadataAssignment
    include Cerberus::Rights::MassPermissions
    include Cerberus::ContentFile::Characterizable
    include Cerberus::Find
    include Cerberus::ImpressionCount
    include Cerberus::MimeTypes

    included do
      attr_accessible :title, :description, :keywords, :identifier
      attr_accessible :depositor, :date, :core_record
      attr_accessible :creators

      has_metadata name: 'DC', type: DublinCoreDatastream
      has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
      has_metadata name: 'properties', type: PropertiesDatastream
      has_file_datastream name: "content", type: FileContentDatastream

      belongs_to :core_record, property: :is_part_of, class_name: 'CoreFile'
    end

    def public?
      self.mass_permissions == "public"
    end

    def klass
      self.class.name
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
  end
end
