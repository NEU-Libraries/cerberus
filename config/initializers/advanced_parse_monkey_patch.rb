module BlacklightAdvancedSearch::ParseBasicQ
  def add_advanced_parse_q_to_solr(solr_parameters, req_params = params)
    begin
      super
    rescue NameError => e
      # Do nothing. Blacklight didn't accomadate for parslet 1.5
      # See https://github.com/kschiess/parslet/blob/master/HISTORY.txt
    end
  end
end
