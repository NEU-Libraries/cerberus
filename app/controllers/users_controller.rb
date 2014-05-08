require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

class UsersController < ApplicationController

  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller

  prepend_before_filter :find_user, :except => [:index, :search, :notifications_number]
  before_filter :authenticate_user!, only: [:edit, :update]
  before_filter :user_is_current_user, only: [:edit, :update]

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
    if user_signed_in? && current_user.nuid == @user.nuid
      self.solr_search_params_logic += [:exclude_unwanted_models]
      (_, @recent_user_documents) = get_search_results(:q =>filter_mine,
                                        :sort=>sort_field, :rows=>3)
    end
  end

  # Display form for users to edit their profile information
  def edit
    @user = current_user
  end

  # Process changes from profile form
  def update

    @user = current_user

    if params[:view_pref].present?
      view_pref  = params[:view_pref]

      #make sure it is only one of these strings
      if view_pref == 'grid' || view_pref == 'list'

        if @user
          unless @user.view_pref == view_pref
            @user.view_pref = view_pref
            @user.save!
          end
        end

      else
        flash[:error] = "Preference wasn't saved, please try again."
      end
    end

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

    respond_to do |format|
      format.html {  redirect_to sufia.profile_path(@user), notice: "Your profile has been updated" }
      format.json { render json: @user.to_json }
      format.js
    end


  end

  protected

  def exclude_unwanted_models(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:NuCoreFile\""
  end

  def depositor
    #Hydra.config[:permissions][:owner] maybe it should match this config variable, but it doesn't.
    Solrizer.solr_name('depositor', :stored_searchable, type: :string)
  end

  def filter_mine
    "{!lucene q.op=AND df=#{depositor}}#{current_user.user_key}"
  end

  def sort_field
    "#{Solrizer.solr_name('system_create', :sortable)} desc"
  end

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

