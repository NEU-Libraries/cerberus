module SetListsHelper

  def recent_deposits
    @set = fetch_solr_document
    @page_title = "#{@set.title} Recent Deposits"
    self.solr_search_params_logic += [:limit_to_core_files]
    # params[:limit] = 10
    if !params[:sort]
      params[:sort] = "#{Solrizer.solr_name('system_create', :stored_sortable, type: :date)} desc"
    end
    if !@set.description.blank?
      @pretty_description = convert_urls(@set.description)
    end
    @pretty_sort_name = pretty_sort_name(params[:sort])
    (@response, @document_list) = get_search_results
    if @response.response['numFound'] > 0
      respond_to do |format|
        format.html { render 'shared/sets/show' }
      end
    else
      redirect_to @set and return
    end
  end

  def creator_list
    @set = fetch_solr_document
    @page_title = "#{@set.title} Creator List"
    self.solr_search_params_logic += [:limit_to_scope]
    self.solr_search_params_logic += [:disable_facet_limit]

    (@response, @document_list) = get_search_results
    solr_fname = "creator_sim"
    @display_facet = @response.facets.detect {|f| f.name == solr_fname}
    if !@set.description.blank?
      @pretty_description = convert_urls(@set.description)
    end
    facet_count = @display_facet.items.length
    if !params[:f].nil?
      render 'shared/sets/show'
    elsif facet_count > 0
      render 'shared/sets/creator_list', locals:{sort_value:sort_value, solr_fname:solr_fname}
    else
      redirect_to @set
    end
  end

  def title_list
    @set = fetch_solr_document
    @page_title = "#{@set.title} Title List"
    self.solr_search_params_logic += [:limit_to_core_files]
    params[:sort] = "#{Solrizer.solr_name('title', :stored_sortable, type: :string)} asc"
    params[:per_page] = @set.all_descendent_files.length
    (@response, @files) = get_search_results
    count = @response.response['numFound']
    if count > 0
      render 'shared/sets/title_list', locals:{sort_value:sort_value, files:@files}
    else
      redirect_to @set
    end
  end

  def smart_col_recent_deposits
    if params[:smart_col].to_s == "communities" || params[:smart_col].to_s == "employees"
      render 'shared/smart_collections/smart_collection', locals: { smart_collection: params[:smart_col] }
    else
      if params[:id]
        smart_col_name = "drs.featured_content.#{params[:smart_col]}.name"
        @page_title = "#{@set.title} #{t(smart_col_name)}"
        @ids = @set.send(params[:smart_col].to_sym)
        self.solr_search_params_logic += [:limit_to_pids]
      else
        smart_col = "#{params[:smart_col]}_filter".parameterize.underscore
        self.solr_search_params_logic += [smart_col.to_sym]
      end
      params[:sort] = "#{Solrizer.solr_name('system_create', :stored_sortable, type: :date)} desc"
      @pretty_sort_name = pretty_sort_name(params[:sort])
      (@response, @document_list) = get_search_results
      if @response.response['numFound'] > 0
        respond_to do |format|
          format.html { render 'shared/smart_collections/smart_collection', locals: { smart_collection: params[:smart_col] } }
        end
      else
        render 'shared/smart_collections/smart_collection', locals: { smart_collection: params[:smart_col] }
      end
    end
  end

  def smart_col_creator_list
    if params[:smart_col].to_s == "communities" || params[:smart_col].to_s == "employees"
      render 'shared/smart_collections/smart_collection', locals: { smart_collection: params[:smart_col] }
    else
      if params[:id]
        smart_col_name = "drs.featured_content.#{params[:smart_col]}.name"
        @page_title = "#{@set.title} #{t(smart_col_name)}"
        @ids = @set.send(params[:smart_col].to_sym)
        self.solr_search_params_logic += [:limit_to_pids]
      else
        smart_col = "#{params[:smart_col]}_filter".parameterize.underscore
        self.solr_search_params_logic += [smart_col.to_sym]
      end
      self.solr_search_params_logic += [:disable_facet_limit]
      (@response, @document_list) = get_search_results
      solr_fname = "creator_sim"
      @display_facet = @response.facets.detect {|f| f.name == solr_fname}
      facet_count = @display_facet.items.length
      if !params[:f].nil?
        redirect_to action:params[:smart_col]
      elsif facet_count > 0
        render 'shared/smart_collections/creator_list', locals:{sort_value:sort_value, solr_fname:solr_fname, smart_collection:params[:smart_col]}
      else
        redirect_to action:params[:smart_col]
      end
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

  def disable_facet_limit(solr_parameters, user_parameters)
    solr_parameters["facet.limit"] = "-1"
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

  def not_root
    if @set.pid == "neu:1"
      redirect_to @set and return
    else
      return false
    end
  end
end
