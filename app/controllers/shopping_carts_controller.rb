class ShoppingCartsController < ApplicationController 

  before_filter :authenticate_user!
  before_filter :session_to_array 
  before_filter :can_dl?, only: [:update]
  

  # Show the user the contents of their shopping cart.
  def show 
    @items = lookup_from_cookie(session[:ids]) 
    @page_title = "Shopping Cart"
  end

  # Allow the user to add/remove items from their shopping cart.
  def update 
    if params[:add]
      @id = params[:add]
      session[:ids] << @id unless session[:ids].include? @id  
    elsif params[:delete]
      @id = params[:delete]
      session[:ids].delete(@id)
      flash.now[:info] = "Item removed from shopping cart" 
    end

    respond_to do |format| 
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
        alert_to_removed_objects
        FileUtils.rm_rf(Dir.glob("#{dir}/*")) if File.directory?(dir) 
        Sufia.queue.push(CartDownloadJob.new(session[:session_id], session[:ids], current_user.nuid))
        @page_title = "Download Shopping Cart"
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

    def alert_to_removed_objects
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
      else
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

        if session[:ids].length >= 1 
          flash.now[:error] = "Can't have more than 100 items in your cart" 
          return
        end
      end
    end

    def lookup_from_cookie(arry)
      if arry
        result = [] 

        # Make sure that we only try to access files that still exist.
        arry.each do |pid| 
          if ActiveFedora::Base.exists?(pid) 
            result << ActiveFedora::Base.find(pid, cast: true) 
          end
        end

        return result
      else
        []
      end
    end
end