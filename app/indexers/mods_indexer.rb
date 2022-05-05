# frozen_string_literal: true

class MODSIndexer
  attr_reader :resource

  def initialize(resource:)
    @resource = resource
  end

  def to_solr
    return {} unless decorated_resource.try(:plain_title)

    {
      title_tsim: decorated_resource.plain_title
    }
  end

  def decorated_resource
    @decorated_resource ||= resource.decorate
  end
end
