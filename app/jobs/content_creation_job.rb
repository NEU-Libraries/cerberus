class ContentCreationJob 

  attr_accessor :core_file_pid, :file_path, :file_name, :user_id 
  attr_accessor :core_record, :user 

  def queue_name 
    :content_creation
  end

  def initialize(core_file, file_path, file_name, user_id) 
    self.core_file_pid = core_file 
    self.file_path     = file_path 
    self.file_name     = file_name 
    self.user_id       = user_id 
  end

  def run
    begin  
      self.user = User.find(user_id) 
      self.core_record = NuCoreFile.find(core_file_pid) 

      content_object = instantiate_appropriate_content_object(file_path, file_name) 


      file_contents = File.open(file_path)
      content_object.add_file(file_contents, 'content', file_name) 
      content_object.core_record =  core_record
      content_object.title       =  file_name
      content_object.identifier  =  content_object.pid
      content_object.depositor   =  user.nuid
      content_object.canonize

      content_object.save!
    ensure 
      temp_dir = file_path.chomp(file_name) 
      FileUtils.rm_rf(temp_dir) 
    end
  end

  private 

    def instantiate_appropriate_content_object(file_path, file_name)

      fmagic = FileMagic.new(FileMagic::MAGIC_MIME).file(file_path) 
      fmagic_result = hash_fmagic(fmagic)

      mime = MIME::Types.of(file_name).first 

      pid = Sufia::Noid.namespaceize(Sufia::IdService.mint) 

      if is_image?(fmagic_result) 
        return ImageMasterFile.new(pid: pid) 
      elsif is_pdf?(fmagic_result)
        return PdfFile.new(pid: pid) 
      elsif is_msword?(fmagic_result, file_name)
        return MswordFile.new(pid: pid) 
      elsif is_msexcel?(fmagic_result, file_name) 
        return MsexcelFile.new(pid: pid) 
      elsif is_msppt?(fmagic_result, file_name) 
        return MspowerpointFile.new(pid: pid) 
      elsif is_texty?(fmagic_result)
        return TextFile.new(pid: pid) 
      else 
        return ZipFile.new(pid: pid) 
      end
    end

    # Takes a string like "image/jpeg ; encoding=binary" 
    # And turns it into the hash {raw_type: 'image', sub_type: 'jpeg', encoding: 'binary'} 
    def hash_fmagic(fmagic_string)
      ary = fmagic_string.split(";") 

      result = {} 
      result[:raw_type] = ary.first.split("/").first.strip
      result[:sub_type] = ary.first.split("/").last.strip
      result[:encoding] = ary.last.split("=").last.strip
      return result
    end

    def is_image?(fm_hash) 
      return fm_hash[:raw_type] == 'image' 
    end

    def is_pdf?(fm_hash) 
      return fm_hash[:sub_type] == 'pdf'
    end

    def is_msword?(fm_hash, fname)
      signature = ['zip', 'msword'].include? fm_hash[:sub_type] 
      file_extension = ['docx', 'doc'].include? fname.split(".").last
      return signature && file_extension 
    end

    def is_msexcel?(fm_hash, fname)
      signature = ['zip', 'vnd.ms-office'].include? fm_hash[:sub_type]
      file_extension = ['xls', 'xlsx', 'xlw'].include? fname.split(".").last 
      return signature && file_extension
    end

    def is_msppt?(fm_hash, fname)
      signature = ['zip', 'vnd.ms-powerpoint'].include? fm_hash[:sub_type] 
      file_extension = ['ppt', 'pptx', 'pps', 'ppsx'].include? fname.split(".").last 
      return signature && file_extension
    end

    def is_texty?(fm_hash) 
      return fm_hash[:raw_type] == 'text' 
    end
end