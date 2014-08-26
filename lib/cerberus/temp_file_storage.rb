module Cerberus::TempFileStorage
  extend ActiveSupport::Concern
  included do
    def move_file_to_tmp(file)
      # We move the file contents to a more permanent location so that our various jobs can access them.
      # An ensure block in that job handles cleanup of this file.
      tempdir = Rails.root.join("tmp")
      new_path = tempdir.join("#{file.original_filename}")
      FileUtils.mv(file.tempfile.path, new_path.to_s)
      return new_path.to_s
    end
  end
end
