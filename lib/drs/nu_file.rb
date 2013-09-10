module Drs
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
  end
end