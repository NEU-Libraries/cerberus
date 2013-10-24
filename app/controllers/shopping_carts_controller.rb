class ShoppingCartsController < ApplicationController 

  before_filter :authenticate_user!
  before_filter :session_to_array 
  before_filter :can_dl?, only: [:update]

  # Show the user the contents of their shopping cart.
  def show 
    @items = lookup_from_cookie(session[:ids]) 
  end

  # Allow the user to add/remove items from their shopping cart.
  def update 
    @id = params[:id]
    @selector_string = ".sc_#{@id}"

    if params[:add]
      session[:ids] << @id unless session[:ids].include? @id  
    elsif params[:delete]
      session[:ids] = session[:ids].delete(@id) if session[:ids]
      flash.now[:info] = "Item removed from shopping cart" 
    end

    respond_to do |format| 
      format.js 
    end
  end

  # Purge the contents of the user's shopping cart. 
  def destroy 
    session[:ids] = nil

    flash.now[:info] = "Sessions successfully cleared" 
    redirect_to shopping_cart_path
  end

  private

    def session_to_array 
      session[:ids] = [] unless session[:ids].instance_of? Array
    end

    def can_dl?
      if params[:add]
        record = ActiveFedora::Base.find(params[:id], cast: true) 
        render_403 unless current_user_can_read?(record)
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