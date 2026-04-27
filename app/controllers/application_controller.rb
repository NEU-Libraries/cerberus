# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  include Authorizable

  before_action do
    I18n.locale = :en
  end

  before_action :store_preferred_view

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  def breadcrumbs(id)
    result = AtlasRb::Resource.find(id)
    item = result.resource
    item.ancestors.each do |ancestor_id, ancestor_klass|
      add_breadcrumb_for(ancestor_id, ancestor_klass)
    end
    add_breadcrumb_for(item.id, result.klass)
  end

  def pretty_group(raw_group)
    Group.find_by(raw: raw_group)&.cosmetic || raw_group
  end

  def store_preferred_view
    session[:preferred_view] = params[:view] if params[:view]
  end

  private # ---------------------------------------------------------

    def add_breadcrumb_for(resource_id, klass)
      title = AtlasRb.const_get(klass).find(resource_id).title
      path  = public_send("#{klass.downcase}_path", resource_id)
      breadcrumb(title, path)
    end
end
