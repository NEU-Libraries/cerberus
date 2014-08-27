module Cerberus::CoreFile::Permissions
  extend ActiveSupport::Concern
  include Hydra::ModelMixins::RightsMetadata

  # Ensures that validations are run on core records and that
  # rightsmetadata mixins are included.
  included do
    has_metadata :name => "rightsMetadata", :type => ParanoidRightsDatastream
    validate :paranoid_permissions
  end

  def paranoid_permissions
    # let the rightsMetadata ds make this determination
    # - the object instance is passed in for easier access to the props ds
    rightsMetadata.validate(self)
  end
end
