require 'spec_helper'

describe CommunitiesController do
  let(:admin)                 { FactoryGirl.create(:admin) }
  let(:bo)                    { FactoryGirl.create(:bo) } 
  let(:root_community)        { FactoryGirl.create(:root_community) }
  let(:test_community)        { FactoryGirl.create(:test_community) }

  describe "GET #index" do
    it "renders the show template for root_community with no user logged in" do      
      get :index
      response.status.should == 302
      expect(response).to redirect_to(community_path(id: 'neu:1'))
    end  
  end

  describe "GET #show" do 
    it "renders the show template for unauthed users on public collections" do 

      get :show, { id: root_community.identifier } 

      expect(response).to render_template('shared/sets/show') 
    end
  end
end