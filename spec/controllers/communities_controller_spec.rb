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

  describe "GET #new" do
    it "renders the new page when the user is an admin" do
      sign_in admin
      get :new
      expect(response).to render_template('communities/new') 
    end

    it "redirects to root_path if the user is not an admin" do
      sign_in bo
      get :new
      expect(response).to redirect_to(root_path)
    end

    it "requests signin from unauthenticated users" do
      get :new
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST #create" do 
    it "requests signin from unauthenticated users" do
      get :new
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to the new show page on successful create" do 
      sign_in admin
      attrs = {title: "Test", description: "test", parent: root_community.id } 

      post :create, {community: attrs} 

      id = assigns(:community).identifier
      expect(response).to redirect_to(community_path(id: id))
    end

    it "redirects to root_path if the user is not an admin" do
      sign_in bo
      get :new
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #show" do 
    it "renders the show template for unauthed users on public collections" do 

      get :show, { id: root_community.identifier } 

      expect(response).to render_template('shared/sets/show') 
    end
  end

  describe "GET #edit" do
    it "requests signin from unauthenticated users" do
      get :new
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to the show page on successful edit by autherized user" do
      sign_in admin
      attrs = {title: "Test title edit", description: "Test edit desc"}
      post :update, {id: test_community.identifier, community: attrs}
      expect(response).to redirect_to(community_path(id: test_community.identifier))

      assigns(:community).title.should == "Test title edit"
      assigns(:community).description.should == "Test edit desc"
    end
  end

  describe "PUTS #update" do
    it "requests signin from unauthenticated users" do
      get :new
      expect(response).to redirect_to(new_user_session_path)
    end
  end

end
