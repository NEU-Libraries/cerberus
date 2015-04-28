class Loaders::ProcessZipJob

  attr_accessor :file, :new_path, :loader

  def queue_name
    :loader_process_zip
  end

  def initialize(file, new_path, loader)
    self.file = file
    self.new_path = new_path
    self.loader = loader
  end

  def run
    # unzip zip file to tmp storage
    puts "we made it to run the job for #{new_path}"
    Zip::Archive.open(file) do |ar|
      n = ar.num_files # number of entries

      n.times do |i|
        entry_name = ar.get_name(i) # get entry name from archive

        # open entry
        ar.fopen(entry_name) do |f| # or ar.fopen(i) do |f|
          file_name = f.name           # name of the file
          size = f.size           # size of file (uncompressed)
          comp_size = f.comp_size # size of file (compressed)
        end
        result = ImageProcessingJob.new(i).run
      end
    end

    # for each file in new dir
      # start a new image_processing_job like...
      # result = ImageProcessingJob.new().run
      # result will be an image_report
    # when all images are processed, create a load_report
  end
end
