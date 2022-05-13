# frozen_string_literal: true

module Modsable
  extend ActiveSupport::Concern
  include MODSToJson

  def mods
    Metadata::MODS.find_or_create_by(valkyrie_id: noid)
  end

  def mods_xml
    return '<_/>' if mods_blob.blank?

    Nokogiri::XML(IO.read(mods_blob&.file_path)) { |doc| doc.noblanks }
    # File.read(mods_blob&.file_path)
  end

  def mods_xml=(raw_xml)
    xml_path = "/home/cerberus/storage/#{Time.now.to_f.to_s.gsub!('.', '-')}.xml"
    File.write(xml_path, raw_xml)
    blob = mods_blob
    # need to amend parent method to allow for inverse if direct isn't available
    parent = Valkyrie.config.metadata_adapter.query_service.find_inverse_references_by(resource: blob,
                                                                                       property: :member_ids).first
    blob.file_identifiers += [create_file(xml_path, parent).id]
    Valkyrie.config.metadata_adapter.persister.save(resource: blob)

    self.mods_json = raw_xml
  end

  def mods_blob
    # need to emulate find or create
    Valkyrie.config.metadata_adapter.query_service.find_inverse_references_by(resource: self,
                                                                              property: :descriptive_metadata_for).first
  end

  def mods_json=(raw_xml)
    mods_json = mods
    mods_json.json_attributes = convert_xml_to_json(raw_xml)
    mods_json.save!
  end
end
