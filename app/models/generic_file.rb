class GenericFile < ActiveFedora::Base
  include Sufia::GenericFile
  # This can be found in our gem fork at: 
  # sufia-models/lib/models/generic_file.rb  

  has_metadata name: 'crud', type: CrudDatastream
  has_metadata name: 'oaidc', type: NortheasternDublinCoreDatastream 

  delegate_to :oaidc, [:nu_title, :nu_type, :nu_identifier] 
end 

