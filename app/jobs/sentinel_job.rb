class SentinelJob
  include ApplicationHelper
  include SentinelHelper

  attr_accessor :sentinel_id

  def initialize(sentinel_id)
    self.sentinel_id = sentinel_id
  end

  def queue_name
    :sentinel_processing
  end

  def run
    sentinel_id = self.sentinel_id

    sentinel = Sentinel.find(sentinel_id)

    set_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{sentinel.set_pid}\"").first

    cf_pids = set_doc.all_descendent_pids

    sentinel.pid_list = cf_pids
    sentinel.save!

    cf_pids.each do |pid|
      apply_permissions(sentinel, pid)
    end
  end

  def apply_permissions(sentinel, core_file_pid)
    doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{core_file_pid}\"").first
    core_file = CoreFile.find(doc.pid)

    # Does the core file have a correctly formatted handle?
    handle = core_file.identifier
    if handle.blank?
      blank_handle = true
      xml = Nokogiri::XML(core_file.mods.content)
      handle = xml.xpath("//mods:identifier[contains(., 'hdl.handle.net')]").text
      core_file.identifier = handle
      core_file.save!
    end

    # Clean the MODS XML Unicode
    core_file.mods.content = xml_decode(core_file.mods.content)

    if !sentinel.core_file.blank?
      core_file.permissions = sentinel.core_file["permissions"]
      core_file.mass_permissions = sentinel.core_file["mass_permissions"]
      core_file.save!
    end

    content_docs = doc.content_objects
    # content_models = content_docs.map{|doc| doc.klass}

    if !sentinel.nil?
      content_docs.each do |content_doc|
        content_object = ActiveFedora::Base.find(content_doc.pid, cast: true)
        # if !model_hsh[content_doc.klass].blank?
          if !sentinel_class_to_symbol(content_doc.klass).blank? && !sentinel.send(sentinel_class_to_symbol(content_doc.klass)).blank?
            content_object.permissions = sentinel.send(sentinel_class_to_symbol(content_doc.klass))["permissions"]
            content_object.mass_permissions = sentinel.send(sentinel_class_to_symbol(content_doc.klass))["mass_permissions"]
            content_object.save!
          end
        # end
      end
    end

    core_file.update_index
  end

end
