require 'spec_helper'

describe EmployeesController do  

  describe "GET #show" do 

    it "doesn't allow unauthenticated access" do 
      get :show 

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "Renders the show page for authenticated users" do 
      user = FactoryGirl.create(:user)
      employee = Employee.create(nuid: user.nuid)  

      sign_in user 

      get :show 

      assigns(:employee).pid.should == employee.pid 
      expect(response).to render_template('employees/show')
    end
  end
end