# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users
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

  resources :communities
  resources :collections
  resources :works
  resources :loads, only: [:index, :show, :new, :create, :destroy]

  get '/downloads/:id', to: 'downloads#show', as: :download

  # xml
  get '/xml/editor/:id' => 'xml#editor', as: 'xml_editor'
  put '/xml/validate' => 'xml#validate'
  put '/xml/update' => 'xml#update'

  # atlas
  get '/atlas/login' => 'atlas#login'
  post '/atlas/process_login' => 'atlas#process_login'
  get '/atlas/user' => 'atlas#user'

  # error pages — also targeted by config.exceptions_app
  match '/403', to: 'errors#forbidden',             via: :all
  match '/404', to: 'errors#not_found',             via: :all
  match '/410', to: 'errors#gone',                  via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
end
