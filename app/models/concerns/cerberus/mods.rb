module Cerberus::Mods
  extend ActiveSupport::Concern
  extend Forwardable

  def_delegators :descMetadata, *ModsMetadata.terminology.terms.keys.concat(ModsMetadata.terminology.terms.keys.map{|x| (x.to_s + "=").to_sym})

  included do
    has_subresource :descMetadata, class_name: 'ModsMetadata'
  end

end
