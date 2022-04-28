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
  end

  def mods_blob
    Valkyrie.config.metadata_adapter.query_service.find_inverse_references_by(resource: self, property: :descriptive_metadata_for).first
  end
end
