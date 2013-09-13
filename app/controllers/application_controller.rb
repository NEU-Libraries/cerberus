class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller 
   include Blacklight::Controller  
  # Adds Sufia behaviors into the application controller 
  include Sufia::Controller

  # Please be sure to impelement current_user and user_session. Blacklight depends on 
  # these methods in order to perform user specific actions. 

  layout :search_layout

  protect_from_forgery

  def render_403 
    render :file => "#{Rails.root}/public/403", formats: [:html], layout: false, status: '403' 
  end

  def mint_unique_pid 
    Sufia::Noid.namespaceize(Sufia::IdService.mint)
  end
end