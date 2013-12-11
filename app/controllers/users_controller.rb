class UsersController < ApplicationController
  extend ActiveSupport::Concern

  included do
    layout "sufia-one-column"
    prepend_before_filter :find_user, :except => [:index, :search, :notifications_number]
    before_filter :authenticate_user!, only: [:edit, :update]
    before_filter :user_is_current_user, only: [:edit, :update]
  end

  def index
    sort_val = get_sort
    query = params[:uq].blank? ? nil : "%"+params[:uq].downcase+"%"
    base = User.where(*base_query)
    unless query.blank?
      base = base.where("#{Devise.authentication_keys.first} like lower(?) OR display_name like lower(?)", query, query)
    end
    @users = base.order(sort_val).page(params[:page]).per(10)

    respond_to do |format|
      format.html
      format.json { render json: @users.to_json }
    end
    
  end

  # Display user profile
  def show
    @user = User.find_by_nuid(params[:id])
    if @user.respond_to? :profile_events
      @events = @user.profile_events(100) 
    else 
      @events = []
    end
  end

  # Display form for users to edit their profile information
  def edit
    @user = current_user
  end

  # Process changes from profile form
  def update
    if params[:user]
      if Rails::VERSION::MAJOR == 3
        @user.update_attributes(params[:user])
      else
        @user.update_attributes(params.require(:user).permit(*User.permitted_attributes))
      end
    end
    @user.populate_attributes if params[:update_directory]
    @user.avatar = nil if params[:delete_avatar]
    unless @user.save
      redirect_to sufia.edit_profile_path(@user), alert: @user.errors.full_messages
      return
    end
    Sufia.queue.push(UserEditProfileEventJob.new(@user.user_key))
    redirect_to sufia.profile_path(@user), notice: "Your profile has been updated"
  end 

  protected

  # You can override base_query to return a list of arguments 
  def base_query
    [nil]
  end

  def find_user
    @user = User.find_by_nuid(params[:id])
    redirect_to root_path, alert: "User '#{params[:id]}' does not exist" if @user.nil?
  end

  def user_is_current_user
    redirect_to sufia.profile_path(@user), alert: "Permission denied: cannot access this page." unless @user == current_user
  end

  def user_not_current_user
    redirect_to sufia.profile_path(@user), alert: "You cannot follow or unfollow yourself" if @user == current_user
  end

  def get_sort
    sort = params[:sort].blank? ? "name" : params[:sort]
    sort_val = case sort
           when "name"  then "display_name"
           when "name desc"   then "display_name DESC"
           else sort
           end
    return sort_val
  end
end

