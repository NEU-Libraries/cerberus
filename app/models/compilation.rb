class Compilation < ActiveFedora::Base
  include Hydra::AccessControls::Permissions
  include Noidable

  # Fedora object which is a thin wrapper around assemblies
  # to tie in with solr/permissions/grouper

  property :assembly_id, predicate: ::RDF::Vocab::DC.identifier, multiple: false do |index|
    index.as :stored_searchable
  end

  def initialize(attributes={})
    super
    if attributes.blank?
      self.assembly_id = (Assembly.create).id
    end
  end

  def assembly
    return Assembly.find(self.assembly_id)
  end

  def ids
    return self.assembly.id_list
  end

  def add(object_id)
    h = {}
    a = self.assembly
    old_list = a.id_list

    if !self.contains? object_id
      if ActiveFedora::SolrService.query("id:#{object_id}").first['has_model_ssim'] == ["Collection"]
        h[object_id] = "collection"
      elsif ActiveFedora::SolrService.query("id:#{object_id}").first['has_model_ssim'] == ["Hydra::Works::Work"]
        h[object_id] = "work"
      else
        # raise error - only collections and works can be added to compilations
      end
      
      new_list = a.id_list.merge h
      a.id_list = new_list
      a.save!
    end
  end

  def remove(object_id)
    # if collection
    # if work
  end

  def contains?(id)
    # find parent if work
    # compare with assembly collections
    # if work compare with assembly works
    return false
  end

  def intersects?(id_list)
    # find collections in list
    # find collections in assembly
    # make sets and compare
  end
end
