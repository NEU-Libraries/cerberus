require 'spec_helper'

describe EmployeesController do

  describe "GET #my_loaders" do
    it "doesn't allow unauthenticated access" do
      get :my_loaders
      expect(response).to redirect_to(new_user_session_path)
    end
    it "renders the users loaders for this authenticated user" do
      user = FactoryGirl.create(:brooks)
      employee = Employee.create(nuid: user.nuid)
      sign_in user
      get :my_loaders
      expect(response).to render_template(:my_loaders)
      sign_out user
    end
    it "renders 403 when user does not have loaders" do
      user = FactoryGirl.create(:admin)
      user_emp = Employee.create(nuid: user.nuid)
      sign_in user
      get :my_loaders
      response.status.should == 403
      sign_out user
    end
  end

  after(:all) do
    ActiveFedora::Base.destroy_all
  end
end
