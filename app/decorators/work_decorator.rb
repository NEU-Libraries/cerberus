# frozen_string_literal: true

module WorkDecorator
  def link
    link_to mods&.resource_type, 'google.com'
  end

  def title
    mods&.title
  end
end
