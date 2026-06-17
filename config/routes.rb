# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users

  authenticate :user, ->(u) { u.groups&.include?(Permissions::STAFF_EDIT_GROUP) } do
    mount MissionControl::Jobs::Engine, at: '/jobs'
  end

  mount Blacklight::Engine => '/catalog'
  root to: 'pages#home'
  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :searchable
  end

  concern :exportable, Blacklight::Routes::Exportable.new

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  resources :bookmarks do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end

  resources :communities, except: [:destroy] do
    member do
      post :tombstone
    end
  end
  resources :collections, except: [:destroy] do
    member do
      post :tombstone
    end
  end
  resources :works, except: %i[index destroy] do
    member do
      get :downloads
      get :manifest
      get :metadata
      patch :metadata, action: :update_metadata
      post :tombstone
    end
  end
  # The bare index is the "My Loaders" interstitial (user-menu entry);
  # everything else on a loader happens through its nested loads.
  resources :loaders, only: [:index], param: :slug do
    resources :loads, only: [:index, :show, :new, :create, :destroy] do
      member { patch :confirm }
    end
  end

  # User Inbox — in-app messaging. destroy is a per-recipient soft-dismiss,
  # not a row delete; recipients is the compose typeahead's JSON source.
  resources :messages, path: 'inbox', only: [:index, :show, :new, :create, :destroy] do
    collection { get :recipients }
  end

  # Sets — personal curated sets over Atlas Compilations ("Set" is the only
  # word a user ever sees; "Compilation" is the model name on the wire).
  # Recipe mutations are member POST/DELETEs mirroring the atlas_rb binding;
  # `aside` is the set-aside / put-back pair.
  resources :sets do
    # picker: the lazy-loaded "Add to set…" menu body (Work/Collection show
    # pages). recipients: typeahead JSON for the Sharing tab's edit_users picker.
    collection do
      get :picker
      get :recipients
    end
    member do
      get    'download',                   to: 'set_downloads#show',     as: :download
      get    'works_count',                to: 'sets#works_count',       as: :works_count
      post   'collections',                to: 'sets#add_collection',    as: :add_collection
      delete 'collections/:collection_id', to: 'sets#remove_collection', as: :remove_collection
      post   'works',                      to: 'sets#add_work',          as: :add_work
      delete 'works/:work_id',             to: 'sets#remove_work',       as: :remove_work
      post   'aside',                      to: 'sets#set_aside',         as: :set_aside
      delete 'aside/:work_id',             to: 'sets#put_back',          as: :put_back
    end
  end

  namespace :admin do
    root to: 'dashboard#index'
    resources :loaders, only: [:index, :new, :create, :edit, :update], param: :slug

    # Re-parent / Move — a self-contained finder: index (find the node) →
    # choose_parent (pick its new parent) → confirm (preview) → move (perform).
    get  'reparent',               to: 'reparent#index'
    get  'reparent/choose_parent', to: 'reparent#choose_parent', as: :reparent_choose_parent
    get  'reparent/confirm',       to: 'reparent#confirm',       as: :reparent_confirm
    post 'reparent/move',          to: 'reparent#move',          as: :reparent_move

    # Linked members — find a Work, then add/remove the Collections it is
    # surfaced in (discovery placement only; never its structural home).
    get    'linked_members',        to: 'linked_members#index'
    get    'linked_members/manage', to: 'linked_members#manage',  as: :linked_members_manage
    post   'linked_members/add',    to: 'linked_members#add',     as: :linked_members_add
    delete 'linked_members/remove', to: 'linked_members#remove',  as: :linked_members_remove

    # Impersonation — a hub action surface (GET) hosting the start form, then
    # begin acting-as (write) or view-as (read-only) for a target NUID; the
    # DELETE (reusing admin_impersonation_path) ends whichever mode is active.
    get    'impersonation', to: 'impersonations#new',              as: :impersonation
    post   'act_as',        to: 'impersonations#create_acting_as', as: :act_as
    post   'view_as',       to: 'impersonations#create_view_as',   as: :view_as
    delete 'impersonation', to: 'impersonations#destroy'
  end

  get '/downloads/:id', to: 'downloads#show', as: :download

  # history — deep diff views reached from the audit-log "View" button.
  # Type-agnostic (the data layer hits Atlas's /resources/:id/* endpoints), so
  # a single flat route serves Work / Collection / Community alike.
  get '/resources/:id/rights_history', to: 'histories#rights', as: :rights_history
  get '/resources/:id/mods_history',   to: 'histories#mods',   as: :mods_history

  # xml
  get '/xml/editor/:id' => 'xml#editor', as: 'xml_editor'
  put '/xml/validate' => 'xml#validate'
  put '/xml/update' => 'xml#update'

  # atlas
  get '/atlas/login' => 'atlas#login'
  post '/atlas/process_login' => 'atlas#process_login'
  get '/atlas/find_or_create' => 'atlas#find_or_create'
  post '/atlas/process_find_or_create' => 'atlas#process_find_or_create'
  get '/atlas/user' => 'atlas#user'

  # error pages — also targeted by config.exceptions_app
  match '/403', to: 'errors#forbidden',             via: :all
  match '/404', to: 'errors#not_found',             via: :all
  match '/410', to: 'errors#gone',                  via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
end
