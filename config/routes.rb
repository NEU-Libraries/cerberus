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

  resources :communities do
    member do
      post :tombstone
    end
  end
  resources :collections do
    member do
      post :tombstone
    end
  end
  resources :works do
    member do
      get :downloads
      get :metadata
      patch :metadata, action: :update_metadata
      post :tombstone
    end
  end
  resources :loads, only: [:index, :show, :new, :create, :destroy]

  namespace :admin do
    resources :loaders, only: [:index, :new, :create, :edit, :update], param: :slug
  end

  get '/downloads/:id', to: 'downloads#show', as: :download

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
