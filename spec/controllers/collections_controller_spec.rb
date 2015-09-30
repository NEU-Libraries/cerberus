require 'spec_helper'

describe CollectionsController do
  let(:admin)            { FactoryGirl.create(:admin) }
  let(:bill)             { FactoryGirl.create(:bill) }
  let(:bo)               { FactoryGirl.create(:bo) }
  let(:root)             { FactoryGirl.create(:root_collection) }
  let(:bills_collection) { FactoryGirl.create(:bills_private_collection) }

  before :all do
    `mysql -u "#{ENV["HANDLE_TEST_USERNAME"]}" < "#{Rails.root}"/spec/fixtures/files/handlesTEST.sql`
    @client = Mysql2::Client.new(:host => "#{ENV["HANDLE_TEST_HOST"]}", :username => "#{ENV["HANDLE_TEST_USERNAME"]}", :password => "#{ENV["HANDLE_TEST_PASSWORD"]}", :database => "#{ENV["HANDLE_TEST_DATABASE"]}")
  end

  describe "GET #index" do
    #TODO Implement
  end

  describe "GET #new" do
    it "redirects to the index page if no parent is set" do
      sign_in bill

      get :new

      expect(response).to redirect_to(root_path)
    end

    it "redirects to the index page if it cannot find the described parent" do
      sign_in bill

      get :new, {parent: 'neu:adsfasdfasdfasdfasdfa' }

      expect(response).to redirect_to(root_path)
    end

    it "renders the new page when a parent is set" do
      sign_in bill

      get :new, { parent: root.pid }

      expect(response).to render_template('shared/sets/new')
    end

    it "requests signin from unauthenticated users" do
      get :new, { parent: root.pid }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders a 403 page for users without edit access to the parent object" do
      sign_in bo

      get :new, {parent: root.pid}

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

    it "redirects to the new show page on successful create" do
      sign_in bill
      attrs = {title: "Test", description: "test", date: Date.today.to_s, parent: bills_collection.id }

      post :create, {set: attrs}

      id = assigns(:set).pid
      expect(response).to redirect_to(collection_path(id: id))
    end

    it "assigns personal collection specific information on successful create" do
      sign_in bill

      employee = Employee.create(nuid: "neu:unique", name: "John Doe")
      employee_root = Collection.create(user_parent: employee.nuid, title: "Root", smart_collection_type: "User Root")
      employee_root.rightsMetadata.permissions({person: bill.nuid}, 'edit')
      employee_root.save!

      post :create, { set: { parent: employee_root.pid, user_parent: employee.nuid, title: "New" } }

      id = assigns(:set).pid
      assigns(:set).smart_collection_type.should == 'miscellany'
      expect(response).to redirect_to(collection_path(id: id))
    end
  end

  describe "GET #show" do

    it "403s for users without read access" do
      sign_in bo

      get :show, { id: bills_collection.pid }

      response.status.should == 403
    end

    it "403s for unauthenticated users when collection is private" do

      get :show, { id: bills_collection.pid }

      response.status.should == 403
    end

    it "renders the show template for unauthed users on public collections" do

      get :show, { id: root.pid }

      expect(response).to render_template('shared/sets/show')
    end

    it "renders the show template for users with proper permissions" do
      sign_in bill

      get :show, { id: bills_collection.pid }

      expect(response).to render_template('shared/sets/show')
    end

    it "renders the 404 template for objects that don't exist" do
      get :show, { id: "neu:xcvsxcvzc" }
      expect(response).to render_template('error/404')
    end

    it "renders the 410 template for objects that have been tombstoned" do
      sign_in admin
      root = Collection.create(title: "Root")
      child_one = Collection.create(title: "Child One", parent: root)
      child_one.tombstone
      get :show, { id: child_one.pid }
      expect(response).to render_template('error/410')
      response.status.should == 410
    end
  end

  describe "GET #edit" do

    it "requests signin from unauthed users" do
      get :edit, { id: bills_collection.pid }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "403s for users without edit access" do
      sign_in bo

      get :edit, { id: bills_collection.pid }

      response.status.should == 403
    end

    it "renders the page for users with edit access" do
      sign_in bill

      get :edit, { id: bills_collection.pid }

      expect(response).to render_template('shared/sets/edit')
    end
  end

  describe "PUTS #update" do
    it "requests signin from unauthenticated users" do
      put :update, { id: root.pid }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "403s when a user without edit access tries to modify a collection" do
      sign_in bo

      put :update, { id: bills_collection.pid, set: {title: "New Title" } }

      response.status.should == 403
    end

    it "does not allow users with read permissions to edit a collection" do
      sign_in bo

      put :update ,{ id: root.pid, :set => { title: "New Title" } }

      response.status.should == 403
    end

    it "succeeds for users with edit permissions on the collection" do
      sign_in bill

      put :update, { id: bills_collection.pid, set: { title: "nu title" } }

      assigns(:set).title.should == "nu title"
      expect(response).to redirect_to(collection_path(id: bills_collection.pid))
    end
  end

  after :all do
    @client.query("DROP DATABASE #{ENV["HANDLE_TEST_DATABASE"]};")
  end
end
