module BlacklightHelper

  include Blacklight::BlacklightHelperBehavior

  def url_for_document(doc, options = {})
    if !doc.nil? && doc['has_model_ssim']
      klass = doc['has_model_ssim'].first.to_s.pluralize.underscore
    else
      return doc
    end

    {controller: klass, action: :show, id: doc}
  end
end
