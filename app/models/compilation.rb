class Compilation < ActiveFedora::Base
  include Hydra::AccessControls::Permissions
  include ApplicationHelper
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
      if solr_query("id:#{object_id}").first['has_model_ssim'] == ["Collection"]
        h[object_id] = "collection"
      elsif solr_query("id:#{object_id}").first['generic_type_ssim'] == ["Work"]
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
    h = {}
    a = self.assembly
    old_list = a.id_list

    new_list = old_list.delete(object_id)
    a.id_list = new_list
    a.save!
  end

  def contains?(object_id)
    parent = solr_query("id:#{object_id}").first.id
    a = self.assembly
    ids = a.id_list.keys

    if ids.include?(object_id) || ids.include?(parent)
      return true
    end

    return false
  end

  def intersects?(new_hash)
    a = self.assembly
    full_old_list = []
    id_list = a.id_list

    work_ids = []
    collection_ids = []

    id_list.each do |entry|
       entry[1] == "collection" ? collection_ids << entry[0] : work_ids << entry[0]
     end

    # add non-collection ids from assembly
    full_old_list << work_ids

    # iterate through collections to get full list of ids
    collection_ids.each do |collection_id|
      solr_query("member_of_collection_ids_ssim:#{collection_id}", true).each do |result|
        full_old_list << result.values
      end
    end

    # ----

    full_new_list = []

    work_ids = []
    collection_ids = []

    new_hash.each do |entry|
      entry[1] == "collection" ? collection_ids << entry[0] : work_ids << entry[0]
    end

    # add non-collection ids from new hash
    full_new_list << work_ids

    # iterate through collections to get full list of ids
    collection_ids.each do |collection_id|
      solr_query("member_of_collection_ids_ssim:#{collection_id}", true).each do |result|
        full_new_list << result.values
      end
    end

    # compare
    return !(full_old_list & full_new_list).blank?
  end
end
