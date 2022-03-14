# frozen_string_literal: true

module ValkyrieHelper
  def create_file(file_path, resource, original_filename = file_path.split('/').last)
    Valkyrie.config.storage_adapter.upload(
      file: File.open(file_path), # tei, png, txt
      resource: resource,
      original_filename: original_filename
    )
  end

  def create_blob(valkyrie_id, file_name, use = Valkyrie::Vocab::PCDMUse.ServiceFile)
    blob = Blob.new
    blob.original_filename = file_name
    blob.file_identifier = valkyrie_id
    blob.use = [use]
    Valkyrie.config.metadata_adapter.persister.save(resource: blob)
  end
end
