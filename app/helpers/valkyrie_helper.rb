# frozen_string_literal: true

module ValkyrieHelper
  def create_file(file_path, resource, original_filename = file_path.split('/').last)
    Valkyrie.config.storage_adapter.upload(
      file: File.open(file_path), # tei, png, txt
      resource: resource,
      original_filename: original_filename
    )
  end
end
