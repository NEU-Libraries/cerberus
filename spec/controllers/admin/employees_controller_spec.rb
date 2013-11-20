require 'spec_helper'

describe Admin::EmployeesController do
  let(:admin)    { FactoryGirl.create :admin } 
  let(:user)     { FactoryGirl.create :user }
  let(:employee) { FactoryGirl.create :employee } 

  before { Employee.destroy_all } 

  describe "GET #index" do 
    context "as an admin" do 
      before { sign_in admin }

      it { render_template "employee/index" } 

      it "assigns the employees variable" do 
        get :index 
        assigns(:employees).should == [] 
      end
    end

    context "as a guest" do 
      it { redirect_to new_user_session_path } 
    end

    context "as a non admin user" do 
      before { sign_in user } 

      it { redirect_to root_path } 
    end
  end

  describe "GET #edit" do 
    let (:employee)  { FactoryGirl.create :employee } 
    let (:community) { FactoryGirl.create :community } 

    context "as an admin" do 
      before { sign_in admin } 

      it "loads the employee" do 
        get :edit, { id: employee.pid } 
        assigns(:employee).should == employee 
      end
    end

    context "as a user" do 
      it { redirect_to root_path } 
    end
  end

  describe "PUT #update" do 
    let(:community)     { FactoryGirl.create :community }

    context "as an admin" do 
      before { sign_in admin } 

      context "from a community edit page" do 
        before :each do
          url = "http://example.com/admin/communities/#{community.pid}/edit"
          @request.env['HTTP_REFERER'] = url
        end

        it "allows addition from a community edit page" do
          put :update, { id: community.pid, admin: { employee: employee.pid } } 
          assigns(:employee).communities.should == [community] 
        end
      end

      context "from an employee edit page" do 
        before(:each) do 
          url = "http://example.com/admin/employees/#{employee.pid}/edit" 
          @request.env['HTTP_REFERER'] = url
        end

        it "adds the specified community to the employee" do 
          put :update, { id: employee.pid, admin: { community: community.pid } } 
          assigns(:employee).communities.should == [community] 
        end

        it "removes the specified community for those sorts of requests" do 
          employee.add_community(community)
          put :update, { id: employee.pid, remove: community.pid }
          assigns(:employee).communities.should == [] 
        end 
      end
    end

    context "as a regular user" do 
      it "doesn't allow update" do 
        put :update, { id: employee.pid, admin: { community: community.pid } } 
        expect(response).to redirect_to new_user_session_path
        assigns(:employee).should be nil 
      end
    end 
  end

  describe "DELETE #destroy" do 
    context "as an admin" do 
      before { sign_in admin } 

      it "allows us to destroy an employee" do 
        pid = employee.pid

        delete :destroy, { id: pid } 
        Employee.exists?(pid).should be false
      end
    end

    context "as a regular user" do 
      it "doesn't allow us to destroy an employee" do 
        pid = employee.pid 

        delete :destroy, { id: pid } 
        Employee.exists?(pid).should be true 
      end
    end
  end
end