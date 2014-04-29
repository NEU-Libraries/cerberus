class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller
   include Blacklight::Controller
  # Adds Sufia behaviors into the application controller
  include Sufia::Controller
  # Solr Escape group values
  include Drs::ControllerHelpers::SolrEscapeGroups

  # Please be sure to impelement current_user and user_session. Blacklight depends on
  # these methods in order to perform user specific actions.

  layout :search_layout

  protect_from_forgery

  # Allows us to redirect to the current page on signin, instead of always back to root.
  def after_sign_in_path_for(resource)
    sign_in_url = url_for(:action => 'new', :controller => 'sessions', :only_path => false, :protocol => 'http')
    if params[:controller] = 'sessions' && params[:action] == 'new' || params[:action] == 'create'
      root_path
    elsif request.referer == sign_in_url
      super
    else
      stored_location_for(resource) || request.referer || root_path
    end
  end

  def render_403
    render :file => "#{Rails.root}/public/403", formats: [:html], layout: false, status: '403'
  end

  def mint_unique_pid
    Sufia::Noid.namespaceize(Sufia::IdService.mint)
  end

  # Why do we have these when current_user.can? is available??
  # helper_method :current_user_can_read?, :current_user_can_edit?

  # # Determine whether or not the viewing user can read this object
  # def current_user_can_read?(fedora_object)
  #   return fedora_object.rightsMetadata.can_read?(current_user)
  # end

  # # Determine whether or not the viewing user can edit this object
  # def current_user_can_edit?(fedora_object)
  #   return fedora_object.rightsMetadata.can_edit?(current_user)
  # end

  # Some useful helpers for seeing the filters defined on given controllers
  # Taken from: http://scottwb.com/blog/2012/02/16/enumerate-rails-3-controller-filters/
  def self.filters(kind = nil)
    all_filters = _process_action_callbacks
    all_filters = all_filters.select{|f| f.kind == kind} if kind
    all_filters.map(&:filter)
  end

  def self.before_filters
    filters(:before)
  end

  def self.after_filters
    filters(:after)
  end

  def self.around_filters
    filters(:around)
  end
end
