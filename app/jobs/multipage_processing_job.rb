class MultipageProcessingJob
  attr_accessor :file_values, :core_file

  def queue_name
    :loader_multipage_processing
  end

  def initialize(file_values, core_file)
    self.file_values = file_values
    self.core_file = core_file
  end

  def run
    begin
      # Make PageFile objects
      # create_all_thumbnail_sizes(master_file_path, thumb_pid)
    rescue Exception => error
      # TODO: fill in
    end
  end

end
