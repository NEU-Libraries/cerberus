Rails.application.routes.draw do
  devise_for :users
  mount Blacklight::Engine => '/catalog'
  root to: "pages#home"
  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
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

  # xml
  get '/xml/editor/:id' => 'xml#editor'
  put '/xml/validate' => 'xml#validate'
  put '/xml/update' => 'xml#update'

end
