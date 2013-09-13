require 'spec_helper'

describe NuCollectionsController do
  let(:bill)             { FactoryGirl.create(:bill) }
  let(:bo)               { FactoryGirl.create(:bo) } 
  let(:root)             { FactoryGirl.create(:root_collection) }
  let(:bills_collection) { FactoryGirl.create(:bills_private_collection) } 

  describe "GET #new" do 
    it "redirects to the index page if no parent is set" do 
      sign_in bill 

      get :new 

      expect(response).to redirect_to(nu_collections_path) 
    end

    it "redirects to the index page if it cannot find the described parent" do 
      sign_in bill 

      get :new, {parent: 'neu:adsfasdfasdfasdfasdfa' } 

      expect(response).to redirect_to(nu_collections_path) 
    end

    it "renders the new page when a parent is set" do 
      sign_in bill

      get :new, { parent: root.identifier } 

      expect(response).to render_template('nu_collections/new') 
    end

    it "requests signin from unauthenticated users" do 
      get :new, { parent: root.identifier } 

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "renders a 403 page for users without edit access to the parent object" do
      sign_in bo 

      get :new, {parent: root.identifier}

      response.status.should == 403 
    end
  end

  describe "GET #show" do 

    it "403s for users without read access" do 
      sign_in bo 

      get :show, { id: bills_collection.identifier }

      response.status.should == 403 
    end

    it "403s for unauthenticated users when collection is private" do 

      get :show, { id: bills_collection.identifier } 

      response.status.should == 403 
    end

    it "renders the show template for unauthed users on public collections" do 

      get :show, { id: root.identifier } 

      expect(response).to render_template('nu_collections/show') 
    end

    it "renders the show template for users with proper permissions" do 
      sign_in bill 

      get :show, { id: bills_collection.identifier } 

      expect(response).to render_template('nu_collections/show') 
    end
  end
end
