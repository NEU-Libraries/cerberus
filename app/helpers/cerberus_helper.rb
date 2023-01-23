module CerberusHelper

  def display_user_name(recent_document)
    return "no display name" unless recent_document.depositor
    return User.find_by_user_key(recent_document.depositor).name rescue recent_document.depositor
  end

  def number_of_deposits(user)
    ActiveFedora::SolrService.query("#{Solrizer.solr_name('depositor', :stored_searchable, :type => :string)}:#{user.user_key}").count
  end

  def link_to_profile(login)
    user = User.find_by_user_key(login)
    return login if user.nil?

    text = if user.respond_to? :name
      user.name
    else
      login
    end

    link_to text, employee_path(user.employee_id)
  end

  def link_to_facet(field, field_string)
    link_to(field, add_facet_params(field_string, field).merge!({"controller" => "catalog", :action=> "index"}))
  end

  def link_to_facet_list(list, field_string, emptyText="No value entered", separator=", ")
    facet_field = Solrizer.solr_name(field_string, :facetable)
    return list.map{ |item| link_to_facet(item, facet_field) }.join(separator) unless list.blank?
    return emptyText
  end

  # Override to remove the label class (easier integration with bootstrap)
  # and handles arrays
  def render_facet_value(facet_solr_field, item, options ={})
    # logger.warn "display value #{ facet_display_value(facet_solr_field, item)}"
    if item.is_a? Array
      render_array_facet_value(facet_solr_field, item, options)
    end

    # Better path, includes the id
    path = params.merge(add_facet_params(facet_solr_field, item.value))

    if params[:action] == "facet"
      path = path.merge(Rails.application.routes.recognize_path(request.referrer))
    end

    if !options[:extended_list].blank?
      return (render_facet_count(item.hits)+ " " + link_to_unless(options[:suppress_link], facet_display_value(facet_solr_field, item), path, :class=>"facet_select")).html_safe
    end

    return (link_to_unless(options[:suppress_link], facet_display_value(facet_solr_field, item), path, :rel => "nofollow", :class=>"facet_select") + " " + render_facet_count(item.hits)).html_safe
  end

  def render_constraints_query(localized_params = params)
    # So simple don't need a view template, we can just do it here.
    if (!localized_params[:q].blank?)
      label =
        if (localized_params[:search_field].blank? || (default_search_field && localized_params[:search_field] == default_search_field[:key] ) )
          nil
        else
          label_for_search_field(localized_params[:search_field])
        end

      render_constraint_element(label,
            localized_params[:q],
            :classes => ["query"],
            :remove => url_for(localized_params.merge(:q=>nil)))
    else
      "".html_safe
    end
  end

end
