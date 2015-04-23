class Loaders::ProcessZipJob
  def queue_name
    :loader_process_zip
  end

  def run
    # unzip zip file to tmp storage
    # for each file in new dir
      # start a new image_processing_job like...
      # result = ImageProcessingJob.new().run
      # result will be a file_report
    # when all images are processed, create a load_report
  end
end
