DrsSufiaApp::Application.routes.draw do
  root :to => "catalog#index"

  Blacklight.add_routes(self)
  HydraHead.add_routes(self)
  Hydra::BatchEdit.add_routes(self)

  resources :nu_collections, except: [:index] 
  get "/nu_collections" => 'nu_collections#show', defaults: { id: "#{Rails.configuration.root_collection_id}" } 

  resources :compilations
  match "/compilations/:id/:entry_id" => 'compilations#delete_file', via: 'delete', as: 'delete_entry' 
  match "/compilations/:id/:entry_id" => 'compilations#add_file', via: 'post', as: 'add_entry'

  get "/files/provide_metadata" => "generic_files#provide_metadata"
  post "/files/process_metadata" => "generic_files#process_metadata"

  get "/files/rescue_incomplete_files" => "generic_files#rescue_incomplete_files", as: 'rescue_incomplete_files'
  match "/incomplete_files" => "generic_files#destroy_incomplete_files", via: 'delete', as: 'destroy_incomplete_files'  

  devise_for :users
  # This must be the very last route in the file because it has a catch all route for 404 errors.
  # This behavior seems to show up only in production mode.
  mount Sufia::Engine => '/'


  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
