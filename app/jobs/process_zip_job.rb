class ProcessZipJob
  attr_accessor :zip_path, :file_name, :file_path, :parent

  def queue_name
    :loader_process_zip
  end

  def initialize(zip_path, file_name, file_path, parent)
    self.zip_path = zip_path
    self.file_name = file_name
    self.file_name = file_path
    self.parent = parent
  end

  def run
    # unzip zip file to tmp storage
    puts "we made it to run the job for #{zip_path}"
    unzip(zip_path)
    # for each file in new dir
      # start a new image_processing_job like...
      # result = ImageProcessingJob.new().run
      # result will be an image_report
    # when all images are processed, create a load_report
  end

  def unzip(file)
  Zip::Archive.open(file) do |zipfile|
    to = File.join(File.dirname(file), File.basename(file, ".*"))
    FileUtils.mkdir(to) unless File.exists? to
    zipfile.each do |f|
      if !f.directory? # Don't extract directories
        fpath = File.join(to, File.basename(f.name))
        open(fpath, 'wb') do |z|
          z << f.read
        end
        result = ImageProcessingJob.new(fpath, parent).run
      end
    end
  end
end
end
