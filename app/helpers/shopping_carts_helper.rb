module ShoppingCartsHelper
  def render_add_to_shopping_cart(pid) 
    link_to("Add to download", 
             update_cart_path(add: pid), 
             :method => 'put', 
             :remote => true)
  end
  

  def render_remove_from_shopping_cart(pid) 
    link_to("Remove from download",
             update_cart_path(delete: pid),
             :method => 'put',
             :remote => true) 
  end
end