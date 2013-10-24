module ShoppingCartsHelper
  def render_add_to_shopping_cart(pid) 
    link_to("Add to download", 
             update_cart_path(id: pid, add: true), 
             :method => 'put', 
             :remote => true)
  end
  

  def render_remove_from_shopping_cart(pid) 
    link_to("Remove from download",
             update_cart_path(id: pid, delete: true),
             :method => 'put',
             :remote => true) 
  end
end