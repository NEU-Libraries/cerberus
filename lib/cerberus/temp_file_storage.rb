module Cerberus::TempFileStorage
  extend ActiveSupport::Concern
  included do
    def move_file_to_tmp(file)
      # We move the file contents to a more permanent location so that our various jobs can access them.
      # An ensure block in that job handles cleanup of this file.
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")

      begin
        uniq_hsh = Digest::MD5.hexdigest("#{file.original_filename}")[0,2]
      rescue NoMethodError
        uniq_hsh = Digest::MD5.hexdigest("#{File.basename(file.path)}")[0,2]
      end

      new_path = tempdir.join("#{Time.now.to_f.to_s.gsub!('.','-')}-#{uniq_hsh}")

      begin
        FileUtils.mv(file.tempfile.path, new_path.to_s)
      rescue NoMethodError
        FileUtils.mv(file.path, new_path.to_s)
      end

      return new_path.to_s
    end

    def copy_file_to_tmp(file)
      # We move the file contents to a more permanent location so that our various jobs can access them.
      # An ensure block in that job handles cleanup of this file.
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")

      begin
        uniq_hsh = Digest::MD5.hexdigest("#{file.original_filename}")[0,2]
      rescue NoMethodError
        uniq_hsh = Digest::MD5.hexdigest("#{File.basename(file.path)}")[0,2]
      end

      new_path = tempdir.join("#{Time.now.to_f.to_s.gsub!('.','-')}-#{uniq_hsh}")

      begin
        FileUtils.cp(file.tempfile.path, new_path.to_s)
      rescue NoMethodError
        FileUtils.cp(file.path, new_path.to_s)
      end
      
      return new_path.to_s
    end
  end
end
