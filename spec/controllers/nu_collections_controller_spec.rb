require 'spec_helper'

describe NuCollectionsController do
  let(:bill)             { FactoryGirl.create(:bill) }
  let(:bo)               { FactoryGirl.create(:bo) } 
  let(:root)             { FactoryGirl.create(:root_collection) }
  let(:bills_collection) { FactoryGirl.create(:bills_private_collection) } 

  describe "GET #index" do 
    #TODO Implement
  end

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

  describe "POST #create" do 
    it "requests signin from unauthenticated users" do 
      post :create, {} 

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "403s when users attempt to create with a parent they cannot edit" do
      sign_in bo

      post :create, { parent: bills_collection.id } 

      response.status.should == 403 
    end

    it "redirects to collections root when a user tries to treat a non-personal folder parent like it is a personal folder" do 
      sign_in bill 

      post :create, { nu_collection: { parent: bills_collection.id, user_parent: bill.nuid } } 

      expect(response).to redirect_to(nu_collections_path)
    end

    it "redirects to the new show page on successful create" do 
      sign_in bill
      attrs = {title: "Test", description: "test", date_of_issue: Date.today.to_s, parent: bills_collection.id } 

      post :create, {nu_collection: attrs} 

      id = assigns(:nu_collection).identifier
      expect(response).to redirect_to(nu_collection_path(id: id))
    end

    it "assigns personal folder specific information on successful create" do
      sign_in bill 

      employee = Employee.create(nuid: "example@example.com", name: "John Doe")  
      employee_root = NuCollection.create(user_parent: employee.pid, title: "Root", personal_folder_type: "user root")
      employee_root.rightsMetadata.permissions({person: bill.nuid}, 'edit')
      employee_root.save!  

      post :create, { nu_collection: { parent: employee_root.pid, user_parent: employee.nuid, title: "New" } }

      id = assigns(:nu_collection).identifier 
      assigns(:nu_collection).personal_folder_type.should == 'miscellany'
      expect(response).to redirect_to(nu_collection_path(id: id))
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

  describe "GET #edit" do 

    it "requests signin from unauthed users" do 
      get :edit, { id: bills_collection.identifier } 

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "403s for users without edit access" do 
      sign_in bo 

      get :edit, { id: bills_collection.identifier } 

      response.status.should == 403 
    end

    it "renders the page for users with edit access" do 
      sign_in bill 

      get :edit, { id: bills_collection.identifier } 

      expect(response).to render_template('nu_collections/edit') 
    end
  end

  describe "PUTS #update" do 
    it "requests signin from unauthenticated users" do 
      put :update, { id: root.identifier } 

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "403s when a user without edit access tries to modify a collection" do 
      sign_in bo 

      put :update, { id: bills_collection.identifier, nu_collection: {title: "New Title" } } 

      response.status.should == 403 
    end

    it "does not allow users with read permissions to edit a collection" do 
      sign_in bo 

      put :update ,{ id: root.identifier, :nu_collection => { title: "New Title" } }

      response.status.should == 403 
    end

    it "succeeds for users with edit permissions on the collection" do 
      sign_in bill 

      put :update, { id: bills_collection.identifier, nu_collection: { title: "nu title" } } 

      assigns(:nu_collection).title.should == "nu title" 
      expect(response).to redirect_to(nu_collection_path(id: bills_collection.identifier))
    end 
  end
end
