module BlacklightHelper

  include Blacklight::BlacklightHelperBehavior

  def url_for_document(doc, options = {})
    #  inherited from lib/blacklight/search_state.rb
    if respond_to?(:blacklight_config) &&
        blacklight_config.show.route &&
        (!doc.respond_to?(:to_model) || doc.to_model.is_a?(SolrDocument))
      route = blacklight_config.show.route.merge(action: :show, id: doc).merge(options)
      route[:controller] = params[:controller] if route[:controller] == :current
      route
    else
      # doc
      if doc['has_model_ssim']
        klass = doc['has_model_ssim'].first.to_s.pluralize.underscore
      else
        klass = "catalog"
      end

      {controller: klass, action: :show, id: doc}
    end
  end

end
