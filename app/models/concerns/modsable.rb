module Modsable
  extend ActiveSupport::Concern

  def mods
    Metadata::MODS.find_or_create_by(valkyrie_id: noid)
  end

  def mods_xml
    return '<_/>' unless mods_blob.present?

    File.read(mods_blob&.file_path)
  end

  def mods_xml=(raw_xml)
    # TODO: allow for easy xml update - neccessary for XML Editor interface
    # Make Blobs versioned
    # Update mods_blob
    xml_path = "/home/cerberus/storage/#{Time.now.to_f.to_s.gsub!('.','-')}.xml"
    File.write(xml_path, raw_xml)
    blob = mods_blob
    parent = Valkyrie.config.metadata_adapter.query_service.find_inverse_references_by(resource: blob, property: :member_ids).first
    blob.file_identifiers += [create_file(xml_path, parent).id] # parent doesn't work...
    Valkyrie.config.metadata_adapter.persister.save(resource: blob)

    mods_json = mods
    mods_json.json_attributes = convert_xml_to_json(raw_xml)
    mods_json.save!
  end

  def mods_blob
    Valkyrie.config.metadata_adapter.query_service.find_inverse_references_by(resource: self, property: :descriptive_metadata_for).first
  end
end
