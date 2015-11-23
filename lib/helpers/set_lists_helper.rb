module SetListsHelper

  def recent_deposits
    @set = fetch_solr_document
    @page_title = "#{@set.title} Recent Deposits"
    self.solr_search_params_logic += [:limit_to_core_files]
    params[:limit] = 10
    if !params[:sort]
      params[:sort] = "#{Solrizer.solr_name('system_create', :stored_sortable, type: :date)} desc"
    end
    @pretty_sort_name = pretty_sort_name(params[:sort])
    (@response, @recent_deposits) = get_search_results
    if @response.response['numFound'] > 0
      respond_to do |format|
        format.html { render 'shared/sets/show' }
      end
    else
      flash[:notice] = "There are no recent deposits"
      redirect_to @set and return
    end
  end

  def author_list
    @set = fetch_solr_document
    @page_title = "#{@set.title} Author List"
    self.solr_search_params_logic += [:limit_to_scope]

    (@response, @document_list) = get_search_results
    solr_fname = "creator_sim"
    @display_facet = @response.facets.detect {|f| f.name == solr_fname}
    facet_count = @display_facet.items.length
    puts "facet count is #{@display_facet.items.length}"
    if facet_count > 0
      render 'shared/sets/author_list', locals:{sort_value:sort_value, solr_fname:solr_fname}
    else
      flash[:notice] = "There are no authors"
      redirect_to @set
    end
  end

  def title_list
    @set = fetch_solr_document
    @page_title = "#{@set.title} Title List"
    self.solr_search_params_logic += [:limit_to_core_files]
    params[:fl] = 'title_ssi, id'

    (@response, @document_list) = get_search_results
    if @response.response['numFound'] > 0
      render 'shared/sets/title_list', locals:{sort_value:sort_value}
    else
      flash[:notice] = "There are no titles"
      redirect_to @set
    end
  end

  def limit_to_core_files(solr_parameters, user_parameters)
    descendents = @set.combined_set_descendents

    # Limit query to items that are set descendents
    # or files off set descendents
    query = descendents.map do |set|
      p = set.pid
      set = "is_member_of_ssim:\"info:fedora/#{p}\""
    end

    # Ensure files directly on scoping collection are added in
    # as well
    query << "is_member_of_ssim:\"info:fedora/#{@set.pid}\""
    fq = query.join(" OR ")
    fq = "(#{fq}) AND active_fedora_model_ssi:\"CoreFile\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << fq
  end

  def pretty_sort_name(sort)
    if sort == "title_ssi asc"
      return "Title"
    elsif sort == "creator_ssi asc"
      return "Creator, A-Z"
    elsif sort == "creator_ssi desc"
      return "Creator, Z-A"
    elsif sort == "system_create_dtsi desc"
      return "Recently added"
    elsif sort == "date_ssi desc"
      return "Recently created"
    elsif sort == "score desc, system_create_dtsi desc"
      return "Relevance"
    end
  end

  def sort_value
    %w[value hits].include?(params[:sort_val]) ? params[:sort_val] : "value"
  end
end
