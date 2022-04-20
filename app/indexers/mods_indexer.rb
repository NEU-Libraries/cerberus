# frozen_string_literal: true

class MODSIndexer
  attr_reader :resource

  def initialize(resource:)
    @resource = resource
  end

  def to_solr
    # return {} unless resource.try(:human_readable_type)

    # {
    #   human_readable_type_ssim: resource.human_readable_type
    # }
  end
end
