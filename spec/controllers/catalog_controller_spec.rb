# frozen_string_literal: true

require 'rails_helper'

describe CatalogController do
  describe 'index' do
    render_views
    it 'renders the index partial' do
      get :index
      expect(response).to render_template('catalog/index')
    end
  end
end
