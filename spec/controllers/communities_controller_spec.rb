require 'spec_helper'

describe CommunitiesController do
  let(:root_community)        { FactoryGirl.create(:root_community) }

  describe "GET #show" do
    it "renders the show template for unauthed users on public collections" do

      get :show, { id: root_community.pid }

      expect(response).to render_template('shared/sets/show')
    end
  end
end
