require 'filemagic'

module Drs::NuFile::MasterCreator 
  extend ActiveSupport::Concern 

  def self.create(core_file, file, datastream_id, user)
    if Drs::NuFile.virus_check(file) != 0 
      raise "#{file.original_filename} cannot be processed" 
    end

    content_object = self.instantiate_appropriate_content_object(file)

    content_object.add_file(file, datastream_id, file.original_filename) 
    content_object.core_record =  core_file
    content_object.title       =  file.original_filename 
    content_object.identifier  =  content_object.pid
    content_object.depositor   =  user.nuid
    content_object.canonize

    begin
      content_object.save!
    rescue RSolr::Error::Http => error
      logger.warn "GenericFilesController::create_and_save_generic_file Caught RSOLR error #{error.inspect}"
      save_tries+=1
      # fail for good if the tries is greater than 3
      raise error if save_tries >=3
      sleep 0.01
      retry
    end
  end

  #private

    def self.instantiate_appropriate_content_object(file)

      fmagic = FileMagic.new(FileMagic::MAGIC_MIME).file(file.path) 
      fmagic_result = hash_fmagic(fmagic)

      fname = file.original_filename
      mime = MIME::Types.of(fname).first 

      pid = Sufia::Noid.namespaceize(Sufia::IdService.mint) 

      if is_image?(fmagic_result) 
        return ImageMasterFile.new(pid: pid) 
      elsif is_pdf?(fmagic_result)
        return PdfFile.new(pid: pid) 
      elsif is_msword?(fmagic_result, fname)
        return MswordFile.new(pid: pid) 
      elsif is_msexcel?(fmagic_result, fname) 
        return MsexcelFile.new(pid: pid) 
      elsif is_msppt?(fmagic_result, fname) 
        return MspowerpointFile.new(pid: pid) 
      elsif is_texty?(fmagic_result)
        return TextFile.new(pid: pid) 
      else 
        return ZipFile.new(pid: pid) 
      end
    end

    def self.hash_fmagic(fmagic_string)
      ary = fmagic_string.split(";") 

      result = {} 
      result[:raw_type] = ary.first.split("/").first.strip
      result[:sub_type] = ary.first.split("/").last.strip
      result[:encoding] = ary.last.split("=").last.strip
      return result
    end

    def self.is_image?(fm_hash) 
      return fm_hash[:raw_type] == 'image' 
    end

    def self.is_pdf?(fm_hash) 
      return fm_hash[:sub_type] == 'pdf'
    end


    def self.is_msword?(fm_hash, fname)
      signature = ['zip', 'msword'].include? fm_hash[:sub_type] 
      file_extension = ['docx', 'doc'].include? fname.split(".").last
      return signature && file_extension 
    end

    def self.is_msexcel?(fm_hash, fname)
      signature = ['zip', 'vnd.ms-office'].include? fm_hash[:sub_type]
      file_extension = ['xls', 'xlsx', 'xlw'].include? fname.split(".").last 
      return signature && file_extension
    end

    def self.is_msppt?(fm_hash, fname)
      signature = ['zip', 'vnd.ms-powerpoint'].include? fm_hash[:sub_type] 
      file_extension = ['ppt', 'pptx', 'pps', 'ppsx'].include? fname.split(".").last 
      return signature && file_extension
    end

    def self.is_texty?(fm_hash) 
      return fm_hash[:raw_type] == 'text' 
    end
end