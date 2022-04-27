# frozen_string_literal: true

class MODSIndexer
  attr_reader :resource

  def initialize(resource:)
    @resource = resource
  end

  def to_solr
    return {} unless resource.try(:mods)

    {
      title_tsim: resource.mods.main_title&.title
    }
  end
end
