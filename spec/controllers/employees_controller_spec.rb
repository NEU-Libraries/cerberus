require 'spec_helper'

describe EmployeesController do  

  describe "GET #personal_graph" do 

    it "doesn't allow unauthenticated access" do 
      get :personal_graph 

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "Renders the users personal folders for this authenticated user." do 
      user = FactoryGirl.create(:user)
      employee = Employee.create(nuid: user.nuid)  

      sign_in user 

      get :personal_graph

      assigns(:employee).pid.should == employee.pid 
      expect(response).to render_template('employees/personal_graph')
    end
  end
end