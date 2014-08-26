module Cerberus
  module ContentFile
    extend ActiveSupport::Concern
    include ActiveModel::MassAssignmentSecurity
    include Hydra::ModelMethods
    include Cerberus::MetadataAssignment
    include Cerberus::Rights::MassPermissions
    include Cerberus::ContentFile::Characterizable
    include Hydra::Derivatives
    include Cerberus::Find
    include Cerberus::ImpressionCount
    include Hydra::ModelMixins::RightsMetadata

    included do
      attr_accessible :title, :description, :keywords, :identifier
      attr_accessible :depositor, :date_of_issue, :core_record
      attr_accessible :creators

      has_metadata name: 'DC', type: DublinCoreDatastream
      has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
      has_metadata name: 'properties', type: PropertiesDatastream
      has_file_datastream name: "content", type: FileContentDatastream

      belongs_to :core_record, property: :is_part_of, class_name: 'CoreFile'
    end

    def public?
      self.rightsMetadata.permissions({group: 'public'}, 'read')
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
      end
    end
  end
end

