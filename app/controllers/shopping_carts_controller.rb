class ShoppingCartsController < ApplicationController

  before_filter :authenticate_user!
  before_filter :session_to_array
  before_filter :can_dl?, only: [:update]
  before_filter :check_availability, only: [:show, :download]


  # Show the user the contents of their shopping cart.
  def show
    @items = lookup_from_cookie(session[:ids])
    @page_title = t('drs.shoppingcarts.name').titlecase
    respond_to do |format|
      format.js
      format.html
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
  # HTML requests bring the user to the download.html page and fire off the zip creation job.
  # JS requests handle eventually triggering the download once on the download page.
  def download
    dir = "#{Rails.root}/tmp/carts/#{session[:session_id]}/"

    respond_to do |format|
      format.html do
        FileUtils.rm_rf(Dir.glob("#{dir}/*")) if File.directory?(dir)
        Sufia.queue.push(CartDownloadJob.new(session[:session_id], session[:ids], current_user.nuid))
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
    f = "#{Rails.root}/tmp/carts/#{session[:session_id]}/cart.zip"
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
        render_403 and return unless current_user_can_read?(record)

        if session[:ids].length >= 100
          flash.now[:error] = "Can't have more than 100 items in your cart"
          return
        end
      end
    end

    def lookup_from_cookie(arry)
      if arry
        x = arry.map { |pid| ActiveFedora::Base.find(pid, cast: true) }
        return x
      else
        []
      end
    end
end
