# frozen_string_literal: true

module WorkDecorator
  def link
    link_to mods&.resource_type, 'google.com'
  end

  def title
    tag.dt('Title') +
      tag.dd("#{mods&.main_title&.nonSort} \
        #{mods&.main_title&.title}: \
        #{mods&.main_title&.subtitle} \
        #{mods&.main_title&.partName} \
        #{mods&.main_title&.partNumber}")
  end
end
