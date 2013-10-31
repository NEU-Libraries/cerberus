require 'spec_helper'

describe CommunitiesController do
  let(:admin)                 { FactoryGirl.create(:admin) }
  let(:bo)                    { FactoryGirl.create(:bo) } 
  let(:root_community)        { FactoryGirl.create(:root_community) }

  describe "GET #index" do
    it "renders the show template for root_community with no user logged in" do      
      get :index
      response.status.should == 302
      expect(response).to redirect_to(community_path(id: 'neu:1'))
    end  
  end 

  describe "GET #new" do
    #
  end

  describe "POST #create" do 
    #
  end

  describe "GET #show" do 
    #
  end

  describe "GET #edit" do
    #
  end

  describe "PUTS #update" do
    #
  end

end
