require 'spec_helper'

describe CollectionsController do
  render_views
  let(:bill)             { FactoryGirl.create(:bill) }
  let(:bo)               { FactoryGirl.create(:bo) }
  let(:root)             { FactoryGirl.create(:root_collection) }
  let(:admin)            { FactoryGirl.create(:admin) }
  let(:bills_collection) { FactoryGirl.create(:bills_private_collection) }
  let(:incomplete_file)  { FactoryGirl.create(:bills_incomplete_file, parent: bills_collection)}
  let(:embargoed_file)   { FactoryGirl.create(:bills_embargoed_file, parent: bills_collection)}

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

  shared_examples_for "show validations" do
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

  describe "GET #show" do
    it_should_behave_like "show validations"
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

    it "renders the page for users with edit access on user's smart collections" do
      sign_in bill

      EmployeeCreateJob.new(bill.nuid, "John Doe").run
      emp = Employee.find_by_nuid(bill.nuid)
      get :edit, { id: emp.smart_collections.last.pid }
      expect(response).to render_template('shared/sets/edit')
    end

    it "renders the page for admin users of regular collections" do
      admin.add_group("northeastern:drs:repository:staff")
      admin.save!
      bills_collection.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")
      bills_collection.save!
      sign_in admin
      get :edit, { id: bills_collection.pid }

      expect(response).to render_template('shared/sets/edit')
    end

    it "renders the page for admin users of smart collections" do
      admin.add_group("northeastern:drs:repository:staff")
      admin.save!
      bills_collection.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")
      bills_collection.save!
      sign_in admin

      EmployeeCreateJob.new(bill.nuid, "John Doe").run
      emp = Employee.find_by_nuid(bill.nuid)
      smart_col = emp.smart_collections.last
      smart_col.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")
      smart_col.save!
      get :edit, { id: smart_col.pid }
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
      root = Collection.create(title: "Root", mass_permissions: "public")
      child_one = Collection.create(title: "Child One", parent: root, mass_permissions: "public", depositor:"000000001")
      sign_in bill

      put :update, { id: child_one.pid, set: { title: "nu title" } }

      assigns(:set).title.should == "nu title"
      expect(response).to redirect_to(collection_path(id: child_one.pid))
    end
  end

  describe "GET #recent_deposits" do
    it_should_behave_like "show validations"

    it "should redirect to collection if no core_files" do
      sign_in bill
      get :recent_deposits, { id: bills_collection.pid }
      doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{bills_collection.pid}\"").first)
      # doc.has_core_file_children?.should == false
      expect(response).to redirect_to(collection_path(id: bills_collection.pid))
    end

    it "should have docs if there are core_files" do
      sign_in bill
      cf = CoreFile.create(title: "Bills Core", parent: bills_collection, mass_permissions: "public", depositor: bill.nuid)
      get :recent_deposits, { id: bills_collection.pid }
      doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{bills_collection.pid}\"").first)
      # doc.has_core_file_children?.should == true
      expected = "/collections/#{bills_collection.pid}/recent"
      request.path.should == expected
      response.body.should =~ /Recent Deposits/m
      response.body.should =~ /Bills Core/m
    end

    it "should respond with rss when asked for it" do
      sign_in bill
      cf = CoreFile.create(title: "Bills Core", parent: bills_collection, mass_permissions: "public", depositor: bill.nuid)
      get :recent_deposits, { id: bills_collection.pid, format: "rss" }
      response.body.should =~ /rss/m
      response.body.should =~ /<item>/m
    end

    it "should not return items which are not public" do
      sign_in bill
      cf = CoreFile.create(title: "Bills Core", parent: bills_collection, mass_permissions: "private", depositor: bill.nuid)
      get :recent_deposits, { id: bills_collection.pid, format: "rss" }
      response.body.should =~ /rss/m
      response.body.should_not =~ /<item>/m
    end

    it "should not return items which are incomplete or in progress" do
      get :recent_deposits, { id: bills_collection.pid, format: "rss" }
      response.body.should =~ /rss/m
      response.body.should_not =~ /<item>/m
    end

    it "should not return items which are embargoed" do
      get :recent_deposits, { id: bills_collection.pid, format: "rss" }
      response.body.should =~ /rss/m
      response.body.should_not =~ /<item>/m
    end
  end

  describe "GET #creator_list" do
    it_should_behave_like "show validations"
    it "should redirect to collection if no core_files" do
      sign_in bill
      get :creator_list, { id: bills_collection.pid }
      doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{bills_collection.pid}\"").first)
      # doc.has_core_file_children?.should == false
      # doc.has_creators?.should == false
      expect(response).to redirect_to(collection_path(id: bills_collection.pid))
    end

    it "should have docs if there are core_files with authors" do
      sign_in bill
      cf = CoreFile.create(title: "Bills Core", parent: bills_collection, mass_permissions: "public", depositor: bill.nuid)
      cf.creators = {'first_names' => ["Billy"],'last_names'  => ["Jean"]}
      cf.save!
      get :creator_list, { id: bills_collection.pid }
      doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{bills_collection.pid}\"").first)
      # doc.has_core_file_children?.should == true
      # doc.has_creators?.should == true
      expected = "/collections/#{bills_collection.pid}/creators"
      request.path.should == expected
      response.body.should =~ /Creator List/m
      response.body.should =~ /Jean, Billy/m
    end
  end

  # describe "GET #title_list" do
  #   it_should_behave_like "show validations"
  #   it "should redirect to collection if no core_files" do
  #     sign_in bill
  #     get :title_list, { id: bills_collection.pid }
  #     doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{bills_collection.pid}\"").first)
  #     # doc.has_core_file_children?.should == false
  #     expect(response).to redirect_to(collection_path(id: bills_collection.pid))
  #   end
  #
  #   it "should have docs if there are core_files" do
  #     sign_in bill
  #     cf = CoreFile.create(title: "Bills Core", parent: bills_collection, mass_permissions: "public", depositor: bill.nuid)
  #     get :title_list, { id: bills_collection.pid }
  #     doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{bills_collection.pid}\"").first)
  #     # doc.has_core_file_children?.should == true
  #     expected = "/collections/#{bills_collection.pid}/titles"
  #     request.path.should == expected
  #     response.body.should =~ /Title List/m
  #     response.body.should =~ /Bills Core/m
  #   end
  # end

  after :all do
    @client.query("DROP DATABASE #{ENV["HANDLE_TEST_DATABASE"]};")
    ActiveFedora::Base.destroy_all
    User.destroy_all
  end
end
