# frozen_string_literal: true

require 'rails_helper'

describe XmlController do
  let(:work) { FactoryBot.create_for_repository(:work) }

  describe 'editor' do
    render_views
    it 'renders the editor partial' do
      get :editor, params: { id: work.noid }
      expect(response).to render_template('xml/editor')
    end
  end
end
