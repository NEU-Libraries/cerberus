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
    respond_to do |format| 
      format.html { render :file => "#{Rails.root}/public/403.html", layout: false, status: '403' } 
    end
  end

  def mint_unique_pid 
    Sufia::Noid.namespaceize(Sufia::IdService.mint)
  end

  def current_user_can_edit_parent?(parent_object)
    return current_user.can? :edit, parent_object
  end

  def can_read? 
    record = ActiveFedora::Base.find(params[:id]) 

    if current_user.nil?
      public_can_read? record
    elsif current_user.can? :read, record 
      return true 
    else
      render_403
    end
  end

  def can_edit?
    record = ActiveFedora::Base.find(params[:id]) 

    if current_user.nil? 
      render_403
    elsif current_user.can? :edit, record 
      return true
    else
      render_403 
    end
  end

  private 

    def public_can_read?(record) 
      record.permissions.each do |perm| 
        is_group = perm[:type] == 'group' 
        is_public = perm[:name] == 'public' 
        is_read = perm[:access] == 'read' 

        if is_group && is_public && is_read
          return true
        end 
      end
      render_403
    end
end