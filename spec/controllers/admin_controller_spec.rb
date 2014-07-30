require 'spec_helper' 

describe AdminController do 

  describe "GET #index" do
    it "redirects to signin on unauthed users" do 
      get :index
      expect(response).to redirect_to(new_user_session_path) 
    end

    it "redirects to root for non admin users" do 
      sign_in (FactoryGirl.create :bill)
      get :index 
      expect(response).to redirect_to(root_path) 
    end

    it "renders the admin home page for admin users" do 
      sign_in (FactoryGirl.create :admin) 
      get :index
      expect(response).to render_template('admin/index') 
    end
  end
end