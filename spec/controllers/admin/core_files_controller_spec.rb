require 'spec_helper'

describe Admin::CoreFilesController do
  render_views
  let(:admin)                 { FactoryGirl.create(:admin) }
  let(:bo)                    { FactoryGirl.create(:bo) }
  let(:bill)                  { FactoryGirl.create(:bill) }
  let(:root) { FactoryGirl.create(:root_collection) }
  let(:file) { FactoryGirl.create(:complete_file,
                                  depositor: "000000001",
                                  parent: root) }
  let(:file2) { FactoryGirl.create(:complete_file,
                                  depositor: "000000001",
                                  parent: root) }

  before :all do
    User.destroy.all
    ActiveFedora::Base.destroy_all
  end

  after :all do
    User.destroy.all
    ActiveFedora::Base.destroy_all
  end

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

  describe "GET #show" do
    it "requests signin from unauthenticated users" do
      file.tombstone
      get :show, { id: file.pid }
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to the show page on successful" do
      sign_in admin
      file.tombstone
      get :show, { id: file.pid }

      expect(response).to render_template "show"
    end

    it "redirects to root_path if the user is not an admin" do
      sign_in bo
      file.tombstone
      get :show, { id: file.pid }
      expect(response).to redirect_to(root_path)
    end

    after(:each) do
      file.revive
    end
  end


  describe "DELETE #destroy" do
    it "requests signin from unauthenticated users" do
      delete :destroy, { id: file.pid }
      expect(response).to redirect_to(new_user_session_path)
    end

    it "removes the core_file" do
      sign_in admin
      pid = file.pid

      delete :destroy, { id: pid }
      expect(response).to redirect_to admin_files_path
      CoreFile.exists?(pid).should be false
    end

    it "redirects to root_path if the user is not an admin" do
      sign_in bo
      delete :destroy, { id: file.pid }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #revive" do
    it "requests signin from unauthenticated users" do
      get :revive, {id: file.pid}
      expect(response).to redirect_to(new_user_session_path)
    end

    it "revives the core_file" do
      sign_in admin
      pid = file.pid
      get :revive, {id: file.pid}
      CoreFile.find(pid).tombstoned?.should be false
      expect(response).to redirect_to admin_files_path
    end

    it "redirects to root_path if the user is not an admin" do
      sign_in bo
      get :revive, {id: file.pid}
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #get_tombstoned" do
    it "requests signin from unauthenticated users" do
      get :get_tombstoned
      expect(response).to redirect_to(new_user_session_path)
    end

    it "gets the tombstoned files" do
      sign_in admin
      file.tombstone
      title = file.title
      xhr :get, :get_tombstoned, :format=>'js'
      expect(response).to render_template(:partial => 'admin/core_files/_core_files')
      response.body.should =~ /#{title}/m
      file.revive
    end

    it "displays message if there are no tombstoned files" do
      sign_in admin
      CoreFile.find(:all).each do |cf|
        if cf.tombstoned?
          cf.revive
        end
      end
      xhr :get, :get_tombstoned, :format=>'js'
      response.body.should =~ /There are currently 0 tombstoned files/m
    end

    it "redirects to root_path if the user is not an admin" do
      sign_in bo
      get :get_tombstoned
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE #multi_delete" do
    it "requests signin from unauthenticated users" do
      delete :multi_delete, { ids: "#{file.pid}, #{file2.pid}" }
      expect(response).to redirect_to(new_user_session_path)
    end

    it "removes the core_file" do
      sign_in admin
      pid = file.pid
      pid2 = file2.pid
      delete :multi_delete, { ids: "#{file.pid}, #{file2.pid}"}
      expect(response).to redirect_to admin_files_path
      CoreFile.exists?(pid).should be false
      CoreFile.exists?(pid2).should be false
    end

    it "redirects to root_path if the user is not an admin" do
      sign_in bo
      delete :multi_delete, { ids: "#{file.pid}, #{file2.pid}" }
      expect(response).to redirect_to(root_path)
    end
  end
end
