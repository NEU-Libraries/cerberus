# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller

  before_action do
    I18n.locale = :en
  end

  before_action :store_preferred_view

  def breadcrumbs(id)
    result = AtlasRb::Resource.find(id)
    klass = result['klass']&.downcase
    item = result['resource']
    item['ancestors'].each do |r|
      breadcrumb(AtlasRb.const_get(r[1]).find(r[0])['title'], public_send("#{r[1].downcase}_path", r[0]))
    end
    breadcrumb(item['title'], public_send("#{klass}_path", item['id']))
  end

  def pretty_group(raw_group)
    Group.find_by(raw: raw_group)&.cosmetic || raw_group
  end

  def store_preferred_view
    session[:preferred_view] = params[:view] if params[:view]
  end
end
