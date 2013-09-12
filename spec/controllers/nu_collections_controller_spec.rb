require 'spec_helper'

describe NuCollectionsController do
  let(:bill) { FactoryGirl.create(:bill) } 
  let(:root) { FactoryGirl.create(:root_collection) } 

  describe "GET #new" do 
    it "redirects to the index page if no parent is set" do 
      sign_in bill 

      get :new 

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
  end
end
