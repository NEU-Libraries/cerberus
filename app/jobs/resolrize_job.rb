class ResolrizeJob
  def queue_name
    :resolrize
  end

  def run
    # Disabling as a result of SolrService's poor thread handling
    # which creates #<ThreadError: can't create Thread (11)> errors

    # require 'active_fedora/version'
    # active_fedora_version = Gem::Version.new(ActiveFedora::VERSION)
    # minimum_feature_version = Gem::Version.new('6.4.4')
    # if active_fedora_version >= minimum_feature_version
    #   ActiveFedora::Base.reindex_everything("pid~#{Cerberus::Application.config.id_namespace}:*")
    # else
    #   ActiveFedora::Base.reindex_everything
    # end
  end
end
