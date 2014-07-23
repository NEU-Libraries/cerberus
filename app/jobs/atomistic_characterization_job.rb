class AtomisticCharacterizationJob

  attr_accessor :content_pid, :c_object

  def queue_name
    :atomistic_characterize
  end

  def initialize(pid)
    self.content_pid = pid
  end

  def run
    self.c_object = ActiveFedora::Base.find(content_pid, cast: true)

    c_object.characterize

    # Disabling the generate_derivatives call.  FTM the notion of
    # content revision on a core record isn't allowed.
    if c_object.canonical?
      # DerivativeCreator.new(content_pid).generate_derivatives
    end
  end
end
