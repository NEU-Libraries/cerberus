# frozen_string_literal: true

module Modsable
  extend ActiveSupport::Concern
  include MODSAssignment
  include MODSBuilder
  include MODSToJson

  def mods
    Metadata::MODS.find_or_create_by(valkyrie_id: noid)
  end

  def mods_xml
    return mods_template if mods_blob.blank? || mods_blob&.file_path

    Nokogiri::XML(File.read(mods_blob&.file_path), &:noblanks).to_s
  end

  def mods_xml=(raw_xml)
    blob = mods_blob
    # need to amend parent method to allow for inverse if direct isn't available
    parent = Valkyrie.config.metadata_adapter.query_service.find_inverse_references_by(resource: blob,
                                                                                       property: :member_ids).first
    blob.file_identifiers += [create_file(write_tmp_xml(raw_xml), parent).id]
    Valkyrie.config.metadata_adapter.persister.save(resource: blob)

    self.mods_json = raw_xml
  end

  def mods_blob
    Valkyrie.config.metadata_adapter.query_service.find_inverse_references_by(resource: self,
                                                                              property: :descriptive_metadata_for).first
  rescue ArgumentError
    nil
  end

  def mods_json=(raw_xml)
    mods_json = mods
    mods_json.json_attributes = convert_xml_to_json(raw_xml)
    mods_json.save!
  end

  private

    def create_file(file_path, resource, original_filename = file_path.split('/').last)
      Valkyrie.config.storage_adapter.upload(
        file: File.open(file_path), # tei, png, txt
        resource: resource,
        original_filename: original_filename
      )
    end

    def write_tmp_xml(raw_xml)
      xml_path = Rails.root.join('tmp', "#{Time.now.to_f.to_s.gsub!('.', '-')}.xml").to_s
      File.write(xml_path, raw_xml)
      xml_path
    end
end
