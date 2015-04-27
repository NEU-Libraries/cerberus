class Loaders::ProcessZipJob
  def queue_name
    :loader_process_zip
  end

  def run
    # unzip zip file to tmp storage
    Zip::Archive.open(new_path) do |ar|
      n = ar.num_files # number of entries

      n.times do |i|
        entry_name = ar.get_name(i) # get entry name from archive

        # open entry
        ar.fopen(entry_name) do |f| # or ar.fopen(i) do |f|
          name = f.name           # name of the file
          size = f.size           # size of file (uncompressed)
          comp_size = f.comp_size # size of file (compressed)
        end
        result = ImageProcessingJob.new(i).run
      end

      # Zip::Archive includes Enumerable
      entry_names = ar.map do |f|
        f.name
      end
    end

    # for each file in new dir
      # start a new image_processing_job like...
      # result = ImageProcessingJob.new().run
      # result will be an image_report
    # when all images are processed, create a load_report
  end
end
