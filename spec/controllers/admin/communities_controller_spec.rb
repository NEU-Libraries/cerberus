require 'spec_helper'

describe Admin::CommunitiesController do
  let(:admin)                 { FactoryGirl.create(:admin) }
  let(:bo)                    { FactoryGirl.create(:bo) }
  let(:root_community)        { FactoryGirl.create(:root_community) }
  let(:test_community)        { FactoryGirl.create(:test_community) }

  describe "GET #index" do
    context "as an admin" do
      before { sign_in admin }
      it { render_template("index") }
    end

    context "as an unauthed user" do
      it { redirect_to(new_user_session_path) }
    end

    context "as a regular user" do
      before { sign_in bo }
      it { redirect_to(root_path) }
    end
  end

  describe "GET #new" do
    it "renders the new page when the user is an admin" do
      sign_in admin
      get :new
      expect(response).to render_template('communities/new')
    end

    it "redirects to root_path if the user is not an admin" do
      sign_in bo
      get :new
      expect(response).to redirect_to(root_path)
    end

    it "requests signin from unauthenticated users" do
      get :new
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST #create" do
    it "requests signin from unauthenticated users" do
      get :new
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to the new show page on successful create" do
      sign_in admin
      attrs = {title: "Test", description: "test", parent: root_community.id }

      post :create, {community: attrs}

      expect(response).to redirect_to admin_communities_path
    end

    it "redirects to root_path if the user is not an admin" do
      sign_in bo
      get :new
      expect(response).to redirect_to(root_path)
    end

    it "redirects to admin communities if thumbnail is not an image" do
      sign_in admin
      file = fixture_file_upload("/files/test.pdf")
      attrs = {title: "Test", description: "test", parent: root_community.id }

      post :create, {community: attrs, thumbnail: file}

      id = assigns(:community).pid
      expect(response).to redirect_to(admin_communities_path)
    end

    it "creates collection thumbnail if thumbnail is an image" do
      sign_in admin
      file = fixture_file_upload("/files/image.png")
      attrs = {title: "Test", description: "test", parent: root_community.id }

      post :create, {community: attrs, thumbnail: file}

      id = assigns(:community).pid
      expect(response).to redirect_to(admin_communities_path)
      set = Community.find(id)
      set.thumbnail_1.should_not be nil
      set.thumbnail_1.should be_instance_of(FileContentDatastream)
    end
  end

  describe "GET #edit" do
    it "requests signin from unauthenticated users" do
      get :new
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "PUTS #update" do
    it "requests signin from unauthenticated users" do
      get :new
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to the show page on successful edit by autherized user" do
      sign_in admin
      attrs = {title: "Test title edit", description: "Test edit desc"}
      put :update, {id: test_community.pid, community: attrs}
      expect(response).to redirect_to admin_communities_path

      assigns(:community).title.should eq "Test title edit"
      assigns(:community).description.should eq "Test edit desc"
    end

    it "redirects to admin communities page if thumbnail is not an image" do
      sign_in admin
      file = fixture_file_upload("/files/test.pdf")
      attrs = {title: "Test title edit", description: "Test edit desc"}
      put :update, {id: test_community.pid, community: attrs, thumbnail: file}

      id = assigns(:community).pid
      expect(response).to redirect_to(admin_communities_path)
    end

    it "creates collection thumbnail if thumbnail is an image" do
      sign_in admin
      file = fixture_file_upload("/files/image.png")
      attrs = {title: "Test title edit", description: "Test edit desc"}

      put :update, {id: test_community.pid, community: attrs, thumbnail: file}

      id = assigns(:community).pid
      expect(response).to redirect_to(admin_communities_path)
      set = Community.find(id)
      set.thumbnail_1.should_not be nil
      set.thumbnail_1.should be_instance_of(FileContentDatastream)
    end
  end

  describe "DELETE #destroy" do

    it "removes the community" do
      sign_in admin
      pid = test_community.pid

      delete :destroy, { id: pid }
      expect(response).to redirect_to admin_communities_path
      Community.exists?(pid).should be false
    end
  end
end
