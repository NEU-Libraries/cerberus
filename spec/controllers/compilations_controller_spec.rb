require 'spec_helper'

describe CompilationsController do
  let(:bill) { FactoryGirl.create(:bill) }
  let(:bo) { FactoryGirl.create(:bo) }
  let(:file) { FactoryGirl.create(:bills_complete_file) }
  let(:collection) { FactoryGirl.create(:bills_private_collection) }

  before :each do
    sign_in bill

    ActiveFedora::Base.find(:all).each do |file|
      file.destroy
    end
  end

  after :each do
    ActiveFedora::Base.find(:all).each do |file|
      file.destroy
    end
  end

  describe "GET #index" do

    it "loads all compilations for which the signed in user is depositor" do
      c = FactoryGirl.create(:bills_compilation)

      get :my_sets

      assigns(:compilations).length.should == ActiveFedora::SolrService.count("depositor_tesim:\"#{bill.nuid}\" AND has_model_ssim:\"#{ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Compilation"}\"")
    end

    it "loads all compilations for which the signed in user has edit permissions" do
      c = FactoryGirl.create(:bos_compilation)
      bill.add_group("special:group")
      bill.save!
      c.rightsMetadata.permissions({group:"special:group"}, "edit")
      c.save!

      get :collaborative_compilations

      u_groups = bill.groups
      query = u_groups.map! { |g| "\"#{g}\""}.join(" OR ")

      assigns(:compilations).length.should == ActiveFedora::SolrService.count("!depositor_tesim:\"#{bill.nuid}\" AND edit_access_group_ssim:(#{query}) OR read_access_group_ssim:(#{query})")
    end

    it "renders the index template" do
      get :index

      expect(response).to render_template('compilations/index')
    end
  end

  describe "GET #new" do

    it "instantiates a blank compilation" do
      get :new

      assigns(:compilation).should be_instance_of(Compilation)
    end

    it "renders the new compilation template for authenticated users" do
      get :new

      expect(response).to render_template('shared/sets/new')
    end

    it "boots out users who aren't signed in" do
      sign_out bill

      get :new

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST #create" do

    it "boots out users who aren't signed in" do
      sign_out bill

      post :create

      expect(response).to redirect_to new_user_session_path
    end

    it "creates a new compilation on successful post" do
      attrs = { 'title' => 'My collection',
                'description' => 'A collection',
                'mass_permissions' => 'public' }

      post :create, :compilation => attrs, :groups => {}

      expect(assigns(:compilation).title).to eq "My collection"
      expect(assigns(:compilation).mass_permissions).to eq "public"

      expect(response).to redirect_to(compilation_path(id: assigns(:compilation).pid))
    end
  end

  describe "GET #show" do
    let(:compilation) { FactoryGirl.create(:bills_compilation) }

    it "boots out users who aren't signed in" do
      sign_out bill

      get :show, :id => compilation.pid

      expect(response.status).to eq 403
    end

    it "renders the template for the depositing owner" do

      get :show, id: compilation.pid

      expect(response).to render_template('shared/sets/show')
    end

    it "renders an error page for users besides the depositor who attempt access" do
      sign_out bill
      sign_in bo

      get :show, id: compilation.pid

      response.status.should == 403
      assigns(:compilation).should be nil
    end

    it "renders the template for user with read or edit permissions" do
      sign_out bill
      bo.add_group("special:group")
      bo.save!
      compilation.rightsMetadata.permissions({group:"special:group"}, "read")
      compilation.save!
      sign_in bo
      get :show, id: compilation.pid

      expect(response).to render_template('shared/sets/show')
    end

    context "with deleted files" do
      # Operating over a copy of the compilation seems to eliminate
      # some strange RELS_EXT behavior that occurs when a file is deleted.
      before :each do
        comp = Compilation.find(compilation.pid)
        comp.add_entry(file)
        comp.save!
        file.delete
      end

      it "purges the deleted objects from the compilation before showing it" do
        get :show, id: compilation.pid
        assigns(:compilation).entry_ids.should == []
      end
    end
    context "with tombstoned files" do
      # Operating over a copy of the compilation seems to eliminate
      # some strange RELS_EXT behavior that occurs when a file is deleted.
      before :each do
        root = Collection.create(title: "Root")
        file = CoreFile.create(title: "Core File One", parent: root, depositor: "nobody@nobody.com")
        comp = Compilation.find(compilation.pid)
        comp.add_entry(file)
        comp.save!
        file.tombstone
        file.save!
      end

      it "purges the deleted objects from the compilation before showing it" do
        get :show, id: compilation.pid
        assigns(:compilation).entry_ids.should == []
      end
    end
  end

  describe "GET #edit" do
    let(:compilation) { FactoryGirl.create(:bills_compilation) }

    it "Boots out users who aren't signed in" do
      sign_out bill

      get :edit, :id => compilation.pid

      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders an error page for users besides the depositor who attempt access" do
      sign_out bill
      sign_in bo

      get :edit, id: compilation.pid

      response.status.should == 403
      assigns(:compilation).should be nil
    end

    it "Shows the edit template to the depositing user" do
      get :edit, id: compilation.pid

      expect(response).to render_template('shared/sets/edit')
      assigns(:compilation).instance_of?(Compilation).should be true
    end

    it "shows the edit template to a user who is not depositor but has edit permissions" do
      sign_out bill
      bo.add_group("special:group")
      bo.save!
      compilation.rightsMetadata.permissions({group:"special:group"}, "edit")
      compilation.save!
      sign_in bo
      get :edit, id: compilation.pid
      expect(response).to render_template('shared/sets/edit')
      assigns(:compilation).instance_of?(Compilation).should be true
    end

    it "renders an error for users who only have read permissions" do
      sign_out bill
      bo.add_group("special:group")
      bo.save!
      compilation.rightsMetadata.permissions({group:"special:group"}, "read")
      compilation.save!
      sign_in bo
      get :edit, id: compilation.pid
      response.status.should == 403
      assigns(:compilation).should be nil
    end
  end

  describe "POST #add_entry" do
    let(:compilation) { FactoryGirl.create(:bills_compilation) }

    it "kicks out unauthenticated users" do
      sign_out bill
      post :add_entry, id: compilation.pid, entry_id: file.pid
      expect(response).to redirect_to new_user_session_path
    end

    it "403s for users without edit permissions" do
      sign_out bill ; sign_in bo
      post :add_entry, id: compilation.pid, entry_id: file.pid
      expect(response.status).to eq 403
    end

    it "Adds the entry and renders nothing for JS requests" do
      post :add_entry, id: compilation.pid, entry_id: file.pid, format: "js"
      expect(response.body).to be_blank
      expect(assigns(:compilation).entry_ids).to include file.pid
    end

    it "Adds the entry and renders nothing for HTML requests" do
      post :add_entry, id: compilation.pid, entry_id: file.pid
      expect(response.body).to redirect_to compilation_path(compilation)
      expect(assigns(:compilation).entry_ids).to include file.pid
    end

    it "Does not allow duplicate entries" do
      cf = CoreFile.create(title:"Core File", parent: collection, depositor: bill.nuid, mass_permissions: "public")
      post :add_entry, id: compilation.pid, entry_id: collection.pid
      post :add_entry, id: compilation.pid, entry_id: cf.pid
      expect(response.body).to be_blank
      expect(response.status).to eq 406
    end
  end

  describe "DELETE #delete_entry" do
    let(:compilation) { FactoryGirl.create(:bills_compilation) }

    it "kicks out unauthenticated users" do
      sign_out bill
      compilation.add_entry file
      delete :delete_entry, id: compilation.pid, entry_id: file.pid
      expect(response).to redirect_to new_user_session_path
    end

    it "403s for users without edit permissions" do
      sign_out bill ; sign_in bo
      compilation.add_entry file
      delete :delete_entry, id: compilation.pid, entry_id: file.pid
      expect(response.status).to eq 403
    end

    it "removes the entry and redirects to the #show action for html requests" do
      compilation.add_entry file
      delete :delete_entry, id: compilation.pid, entry_id: file.pid
      expect(response).to redirect_to compilation_path(compilation)
      expect(assigns(:compilation).entry_ids).not_to include file.pid
    end

    it "removes the entry and does nothing for .js requests" do
      compilation.add_entry file
      delete :delete_entry, id: compilation.pid, entry_id: file.pid, format: "js"
      expect(response.body).to be_blank
      expect(assigns(:compilation).entry_ids).not_to include file.pid
    end
  end

  describe "GET #get_total_count" do
    let(:compilation) { FactoryGirl.create(:bills_compilation) }
    it "retrieves total core file count recursively" do
      cf = CoreFile.create(title:"Core File", parent: collection, depositor: bill.nuid, mass_permissions: "public")
      post :add_entry, id: compilation.pid, entry_id: collection.pid
      post :add_entry, id: compilation.pid, entry_id: file.pid
      get :get_total_count, id: compilation.pid
      expect(assigns(:count)).to eq 2
    end
  end
end
