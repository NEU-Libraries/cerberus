# frozen_string_literal: true

class GatedSearchService < Blacklight::SearchService
  def current_user
    context[:current_user]
  end

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end
end
