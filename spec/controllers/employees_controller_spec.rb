require 'spec_helper'

describe EmployeesController do

  describe "GET #personal_graph" do

    it "doesn't allow unauthenticated access" do
      get :personal_graph

      expect(response).to redirect_to(new_user_session_path)
    end

    it "Renders the users personal smart_collections for this authenticated user." do
      user = FactoryGirl.create(:user)
      employee = Employee.create(nuid: user.nuid)

      sign_in user

      get :personal_graph

      assigns(:employee).pid.should == employee.pid
      expect(response).to render_template('employees/personal_graph')
      sign_out user
    end
  end

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
      assigns(:employee).pid.should == employee.pid
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

  describe "GET #loaders" do
    it "renders 403 when user is auth but not self"
      # admin = FactoryGirl.create(:admin)
      # admin_emp = Employee.create(nuid: admin.nuid)
      # user = FactoryGirl.create(:brooks)
      # employee = Employee.create(nuid: user.nuid)
      # sign_in admin
      # get :loaders { employee.pid => employee.pid}
      # response.status.should == 403
      # sign_out admin
    end
  end

  #destroy users and employees?
end
