class GenericFile < ActiveFedora::Base
  include Sufia::GenericFile
  # This can be found in our gem fork at: 
  # sufia-models/lib/models/generic_file.rb  

  has_metadata name: 'crud', type: CrudDatastream
  has_metadata name: 'oaidc', type: NortheasternDublinCoreDatastream 

  delegate_to :oaidc, [:nu_title, :nu_type, :nu_identifier, :nu_description]

  def self.create_metadata(generic_file, user, batch_id, collection_id)
    generic_file.apply_depositor_metadata(user.user_key)
    generic_file.date_uploaded = Date.today
    generic_file.date_modified = Date.today
    generic_file.creator = user.name

    if batch_id
      generic_file.add_relationship("isPartOf", "info:fedora/#{Sufia::Noid.namespaceize(batch_id)}")
    else
      logger.warn "unable to find batch to attach to"
    end

    if collection_id
      generic_file.add_relationship("isPartOf", "info:fedora/#{Sufia::Noid.namespaceize(collection_id)}")
    else
      logger.warn "unable to find collection to attach to"
    end

    yield(generic_file) if block_given?
    generic_file.save!
  end   
end 

