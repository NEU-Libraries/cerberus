module Modsable
  extend ActiveSupport::Concern
  extend Forwardable

  included do
    has_subresource 'descMetadata', class_name: 'ModsMetadata'
  end
  
  def_delegators :descMetadata, *ModsMetadata.terminology.terms.keys.concat(ModsMetadata.terminology.terms.keys.map{|x| (x.to_s + "=").to_sym})
end
