module NuFile
  extend ActiveSupport::Concern
  include Hydra::ModelMethods

  included do
  	has_metadata name: 'DC', type: NortheasternDublinCoreDatastream 
  	has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
    has_file_datastream :name => "content", :type => FileContentDatastream
    
    belongs_to :nu_core_files, :property => :is_part_of, :class_name => 'NuCoreFile'

    delegate_to :DC, [:nu_title, :nu_description, :nu_identifier]
  end
end