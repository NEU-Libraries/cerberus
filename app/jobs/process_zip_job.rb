class ProcessZipJob
  attr_accessor :new_path

  def queue_name
    :loader_process_zip
  end

  def initialize(new_path)
    self.new_path = new_path
  end

  def run
    # unzip zip file to tmp storage
    puts "we made it to run the job for #{new_path}"
    Zip::Archive.open(new_path) do |ar|
      ar.each do |zf|
        if zf.directory?
          FileUtils.mkdir_p(zf.name)
        else
          dirname = File.dirname(ar.name)
          FileUtils.mkdir_p(dirname) unless File.exist?(dirname)
          puts dirname
          open(zf.name, 'wb') do |f|
            f << zf.read
            puts zf.name
          end
        end
      end
      # n = ar.num_files # number of entries
      # puts n
      # n.times do |i|
      #   entry_name = ar.get_name(i) # get entry name from archive
      #
      #   # open entry
      #   ar.fopen(i) do |f| # or ar.fopen(i) do |f|
      #     file_name = f.name           # name of the file
      #     size = f.size           # size of file (uncompressed)
      #     comp_size = f.comp_size # size of file (compressed)
      #     puts file_name
      #   end
      #   result = ImageProcessingJob.new(i).run
      # end
    end

    # for each file in new dir
      # start a new image_processing_job like...
      # result = ImageProcessingJob.new().run
      # result will be an image_report
    # when all images are processed, create a load_report
  end
end
