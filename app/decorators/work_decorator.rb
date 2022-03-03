# frozen_string_literal: true

module WorkDecorator
  def link
    link_to mods&.resource_type, 'google.com'
  end

  def title
    tag.dt('Title') +
      tag.dd("#{mods&.title&.nonSort} \
        #{mods&.title&.title}: \
        #{mods&.title&.subtitle} \
        #{mods&.title&.partName} \
        #{mods&.title&.partNumber}")
  end
end
