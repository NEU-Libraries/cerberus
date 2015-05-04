class ProcessZipJob
  attr_accessor :loader_name, :zip_path, :parent, :copyright, :current_user

  def queue_name
    :loader_process_zip
  end

  def initialize(loader_name, zip_path, parent, copyright, current_user)
    self.loader_name = loader_name
    self.zip_path = zip_path
    self.parent = parent
    self.copyright = copyright
    self.current_user = current_user
  end

  def run
    # unzip zip file to tmp storage
    unzip(zip_path)
    # for each file in new dir
      # start a new image_processing_job like...
      # result = ImageProcessingJob.new().run
      # result will be an image_report
    # when all images are processed, create a load_report
    results = []
    Loaders::LoadReport.create_from_strings(current_user, Time.new, results, loader_name)

  end

  def unzip(file)
  Zip::Archive.open(file) do |zipfile|
    to = File.join(File.dirname(file), File.basename(file, ".*"))
    FileUtils.mkdir(to) unless File.exists? to
    zipfile.each do |f|
      if !f.directory? && File.basename(f.name)[0..1] != "._" # Don't extract directories
        fpath = File.join(to, File.basename(f.name))
        open(fpath, 'wb') do |z|
          z << f.read
        end
        result = ImageProcessingJob.new(fpath, parent, copyright, current_user).run
      end
    end
  end
end
end
