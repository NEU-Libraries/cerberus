class ReconcileCompilationsJob
  include ApplicationHelper

  attr_accessor :core_file_pid

  def queue_name
    :reconcile_compilations
  end

  def initialize(pid)
    self.core_file_pid = pid
  end

  def run
    cf_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{self.core_file_pid}\"").first
    parent_pid = cf_doc.parent

    # Get all compilation docs
    compilation_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Compilation"
    compilations = solr_query("has_model_ssim:#{compilation_model}")

    compilations.each do |comp|
      entry_ids = comp.entry_ids

      # Does this compilation contain the new parent collection?
      if entry_ids.include?(parent_pid)
        # Does this compilation also contain the moved file?
        if entry_ids.include?(self.core_file_pid)
          compilation = Compilation.find(comp.id)
          compilation.remove_entry(self.core_file_pid)
          compilation.save!
        end
      end
    end
  end
end
