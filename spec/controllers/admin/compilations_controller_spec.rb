require 'spec_helper'

describe Admin::CompilationsController do
  let(:admin)                 { FactoryGirl.create(:admin) }
  let(:bill)                  { FactoryGirl.create(:bill) }
  let(:file)                  { FactoryGirl.create(:bills_complete_file) }
  let(:compilation)           { FactoryGirl.create(:bills_compilation) }


  describe "GET #index" do
    it "should render index as admin" do
      sign_in admin
      get :index
      expect(response).to render_template "index"
    end

    it "should redirect for unauth user" do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    it "should redirect for regular user" do
      sign_in bill
      get :index
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #edit" do
    it "requests signin from unauthenticated users" do
      get :edit, id: compilation.pid
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders template for admin" do
      sign_in admin
      get :edit, id: compilation.pid
      expect(response).to render_template "edit"
    end

    it "redirects for regular user" do
      sign_in bill
      get :edit, id: compilation.pid
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PUTS #update" do
    it "requests signin from unauthenticated users" do
      get :update, id: compilation.pid
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects for regular user" do
      sign_in bill
      get :update, id: compilation.pid
      expect(response).to redirect_to(root_path)
    end

    it "redirects to the show page on successful edit by autherized user" do
      sign_in admin
      attrs = {title: "Test title edit", description: "Test edit desc"}
      put :update, {id: compilation.pid, compilation: attrs}
      expect(response).to redirect_to admin_compilations_path

      assigns(:compilation).title.should eq "Test title edit"
      assigns(:compilation).description.should eq "Test edit desc"
    end
  end

  describe "DELETE #destroy" do

    it "removes the compilation" do
      sign_in admin
      pid = compilation.pid

      delete :destroy, { id: pid }
      expect(response).to redirect_to admin_compilations_path
      Compilation.exists?(pid).should be false
    end
  end
end
