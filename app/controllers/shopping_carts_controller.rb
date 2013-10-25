class ShoppingCartsController < ApplicationController 

  before_filter :authenticate_user!
  before_filter :can_dl?, only: [:update]
  before_filter :session_to_array 
  

  # Show the user the contents of their shopping cart.
  def show 
    @items = lookup_from_cookie(session[:ids]) 
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

    flash.now[:info] = "Sessions successfully cleared" 
    redirect_to shopping_cart_path
  end

  # Zip and serve the user's added items.
  # HTML requests bring the user to the download.html page and fire off the zip creation job. 
  # JS requests handle eventually triggering the download once on the download page. 
  def download
    respond_to do |format|
      format.html { Sufia.queue.push(CartDownloadJob.new(session[:ids], current_user.nuid)) } 

      format.js do

        dir = "#{Rails.root}/tmp/#{current_user.nuid}/cart"
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
    f = "#{Rails.root}/tmp/#{current_user.nuid}/cart/cart.zip" 
    send_data(f, filename: "downloads.zip")
  end

  private

    def session_to_array 
      session[:ids] ||= [] 
    end

    def can_dl?
      if params[:add]
        record = ActiveFedora::Base.find(params[:add], cast: true) 
        render_403 and return unless current_user_can_read?(record)
      end
    end

    def lookup_from_cookie(arry)
      if arry 
        x = arry.map { |p| ActiveFedora::Base.find(p, cast: true) } 
        return x
      else
        []
      end
    end
end