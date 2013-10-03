require 'spec_helper'

describe DepartmentsController do
  let(:bill)             { FactoryGirl.create(:bill) }
  let(:bo)               { FactoryGirl.create(:bo) } 
  let(:root_dept)        { FactoryGirl.create(:root_department) }

  describe "GET #index" do 
    #TODO Implement
  end

  describe "GET #new" do 
    it "redirects to the index page if no parent is set" do 
      sign_in bill 

      get :new 

      expect(response).to redirect_to(departments_path) 
    end

    it "redirects to the index page if it cannot find the described parent" do 
      sign_in bill 

      get :new, {parent: 'neu:adsfasdfasdfasdfasdfa' } 

      expect(response).to redirect_to(departments_path) 
    end

    it "renders the new page when a parent is set" do 
      sign_in bill

      get :new, { parent: root_dept.identifier } 

      expect(response).to render_template('new') 
    end

    it "requests signin from unauthenticated users" do 
      get :new, { parent: root_dept.identifier } 

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "renders a 403 page for users without edit access to the parent object" do
      sign_in bo 

      get :new, {parent: root_dept.identifier}

      response.status.should == 403 
    end
  end

  describe "POST #create" do 
    it "requests signin from unauthenticated users" do 
      post :create, {} 

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "403s when users attempt to create with a parent they cannot edit" do
      sign_in bo

      post :create, { parent: root_dept.id } 

      response.status.should == 403 
    end

    it "redirects to the new show page on successful create" do 
      sign_in bill
      attrs = {title: "Test", description: "test", parent: root_dept.id } 

      post :create, {set: attrs} 

      id = assigns(:set).identifier
      expect(response).to redirect_to(department_path(id: id))
    end
  end

  describe "GET #show" do 

    it "renders the show template for unauthed users on public departments" do 

      get :show, { id: root_dept.identifier } 

      expect(response).to render_template('shared/sets/show') 
    end

    it "renders the show template for users with proper permissions" do 
      sign_in bill 

      get :show, { id: root_dept.identifier } 

      expect(response).to render_template('shared/sets/show') 
    end
  end

  describe "GET #edit" do 

    it "requests signin from unauthed users" do 
      get :edit, { id: root_dept.identifier } 

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "403s for users without edit access" do 
      sign_in bo 

      get :edit, { id: root_dept.identifier } 

      response.status.should == 403 
    end

    it "renders the page for users with edit access" do 
      sign_in bill 

      get :edit, { id: root_dept.identifier } 

      expect(response).to render_template('edit') 
    end
  end

  describe "PUTS #update" do 
    it "requests signin from unauthenticated users" do 
      put :update, { id: root_dept.identifier } 

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "403s when a user without edit access tries to modify a department" do 
      sign_in bo 

      put :update, { id: root_dept.identifier, set: {title: "New Title" } } 

      response.status.should == 403 
    end

    it "does not allow users with read permissions to edit a department" do 
      sign_in bo 

      put :update ,{ id: root_dept.identifier, :set => { title: "New Title" } }

      response.status.should == 403 
    end

    it "succeeds for users with edit permissions on the department" do 
      sign_in bill 

      put :update, { id: root_dept.identifier, set: { title: "nu title" } } 

      assigns(:set).title.should == "nu title" 
      expect(response).to redirect_to(department_path(id: root_dept.identifier))
    end 
  end
end
