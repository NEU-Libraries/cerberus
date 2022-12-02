# frozen_string_literal: true

require 'rails_helper'

describe WorksController do
  let(:work) { FactoryBot.create_for_repository(:work) }

  describe 'show' do
    render_views
    it 'renders the show partial' do
      # More complex metadata touches means more decorator coverage
      work.mods_xml = File.read('/home/cerberus/web/spec/fixtures/files/work-mods.xml')
      expect(work.decorate.plain_title).to eq("What's New - How We Respond to Disaster, Episode 1")

      get :show, params: { id: work.noid }
      expect(response).to render_template('works/show')
      expect(CGI.unescapeHTML(response.body)).to include(work.plain_title)
    end
  end
end
