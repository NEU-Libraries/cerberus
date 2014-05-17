class ShoppingCartsController < ApplicationController

  before_filter :authenticate_user!
  before_filter :session_to_array
  before_filter :can_dl?, only: [:update]
  before_filter :check_availability, only: [:show, :download]

  # Here be solr access boilerplate
  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)
  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller


  def show
    if !session[:ids].empty?
      self.solr_search_params_logic += [:find_all_objects_from_cookie]
      (@response, @document_list) = get_search_results
      @items = @response.docs

      self.solr_search_params_logic.delete(:find_all_objects_from_cookie)

      self.solr_search_params_logic += [:find_all_objects_from_core_ids]
      (@response, @document_list) = get_search_results
      @item_core_records = @response.docs

      # Sort @items and @item_core_records so that it can be assumed that
      # @item_core_records.fetch(i) gets the core record specifically for
      # @items.fetch(i)
      @items.sort_by! { |hsh| hsh["is_part_of_ssim"] }
      @item_core_records.sort_by! { |hsh| hsh["id"] }
    else
      @items = []
      @item_core_records = []
    end
  end

  # Allow the user to add/remove items from their shopping cart.
  def update
    if params[:add]
      @id = params[:add]
      session[:ids] << @id unless session[:ids].include? @id
      flash.now[:info] = "Item added to #{t('drs.shoppingcarts.name')}."
    elsif params[:delete]
      @id = params[:delete]
      session[:ids].delete(@id)
      flash.now[:info] = "Item removed from #{t('drs.shoppingcarts.name')}."
    end

    respond_to do |format|
      format.html { redirect_to shopping_cart_path }
      format.js
    end
  end

  # Purge the contents of the user's shopping cart.
  def destroy
    session[:ids] = []

    flash[:info] = "Sessions successfully cleared"
    redirect_to shopping_cart_path
  end

  # Zip and serve the user's added items.
  # HTML requests bring the user to the download.html page and fire off the cart download job.
  # JS requests handle eventually triggering the download once on the download page.
  def download
    dir = "#{Rails.root}/tmp/carts/#{session[:session_id]}/"

    respond_to do |format|
      format.html do
        FileUtils.rm_rf(Dir.glob("#{dir}/*")) if File.directory?(dir)
        Drs::Application::Queue.push(CartDownloadJob.new(session[:session_id], session[:ids], current_user.nuid, request.remote_ip))
        @page_title = "Start Download - #{t('drs.shoppingcarts.name')}"
      end

      format.js do
        attempts = 25

        until attempts == 0 do
          sleep(2)

          if !Dir[dir].empty?
            render("download")
            break
          else
            attempts -= 1
          end
        end
        return
      end
    end
  end

  # Actually trigger a download.
  def fire_download
    f = "#{Rails.root}/tmp/carts/#{session[:session_id]}/drs_queue.zip"
    send_file(f)
  end

  private

    # Before critical actions (showing all downloads, actually firing a download)
    # Filter out pids that might no longer exist in the repository and alert the
    # user that this has occurred.
    def check_availability
      deleted = []

      session[:ids].each do |pid|
        if !ActiveFedora::Base.exists?(pid)
          session[:ids].delete(pid)
          deleted << pid
        end
      end

      if !deleted.empty? && session[:ids].empty?
        flash[:error] = "All items associated with this cart have been deleted.  Cancelling Download"
        redirect_to shopping_cart_path and return
      elsif !deleted.empty?
        flash.now[:error] = "The following items no longer exist in the" +
        " repository and have been removed from your cart:" +
        " #{deleted.join(', ')}"
      end
    end

    def session_to_array
      session[:ids] ||= []
    end

    # Verify the user can add this item to their shopping cart.
    # And that doing so wouldn't cause them to over the 100 pid
    # limit
    def can_dl?
      if params[:add]
        record = ActiveFedora::Base.find(params[:add], cast: true)
        render_403 and return unless (current_user.can? :read, record)

        if session[:ids].length >= 100
          flash.now[:error] = "Can't have more than 100 items in your cart"
          return
        end
      end
    end

    def find_all_objects_from_core_ids(solr_parameters, user_parameters)
      core_ids = @items.map { |x| x["is_part_of_ssim"].first }
      core_ids.map! { |x| x.split("/").last }

      id_to_query = core_ids.map { |x| "id:\"#{x}\"" }
      filter_query = id_to_query.join(" OR ")

      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << filter_query
    end

    def find_all_objects_from_cookie(solr_parameters, user_parameters)
      id_to_query = session[:ids].map { |x| "id:\"#{x}\"" }
      filter_query = id_to_query.join(" OR ")

      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << filter_query
    end
end
