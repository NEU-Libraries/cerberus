# frozen_string_literal: true

module PeopleHelper
  # The header's name: a link to the person's own profile, or plain text for a
  # signed-in user with no Person, so the name never leads to a dead end.
  def own_profile_name(name, link_class:, text_class:)
    noid = own_profile_noid
    noid ? link_to(name, person_path(noid), class: link_class) : tag.span(name, class: text_class)
  end
end
