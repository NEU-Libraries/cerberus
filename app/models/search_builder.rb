# frozen_string_literal: true
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include Hydra::AccessControlsEnforcement

  ##
  # @example Adding a new step to the processor chain
  #   self.default_processor_chain += [:add_custom_data_to_query]
  #
  #   def add_custom_data_to_query(solr_parameters)
  #     solr_parameters[:custom] = blacklight_params[:user_value]
  #   end

  self.default_processor_chain += [:exclude_unwanted_models]

  def exclude_unwanted_models(solr_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "-#{Solrizer.solr_name("has_model", :symbol)}:\"ActiveFedora::IndirectContainer\""
    solr_parameters[:fq] << "-#{Solrizer.solr_name("has_model", :symbol)}:\"ActiveFedora::Aggregation::Proxy\""
  end

  def limit_to_collection_children(solr_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "member_of_collection_ids_ssim:\"#{blacklight_params[:item_id]}\" OR isPartOf_ssim:\"#{blacklight_params[:item_id]}\""
  end
end
