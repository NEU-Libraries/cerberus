module Cerberus::TempFileStorage
  extend ActiveSupport::Concern
  included do
    def move_file_to_tmp(file)
      # We move the file contents to a more permanent location so that our various jobs can access them.
      # An ensure block in that job handles cleanup of this file.
      if Rails.env.production?
        tempdir = Pathname.new("/tmp/DRStmp/")
      else
        tempdir = Rails.root.join("tmp")
      end
      uniq_hsh = Digest::MD5.hexdigest("#{file.original_filename}")[0,2]
      new_path = tempdir.join("#{Time.now.to_i.to_s}-#{uniq_hsh}")
      FileUtils.mv(file.tempfile.path, new_path.to_s)
      return new_path.to_s
    end
  end
end
