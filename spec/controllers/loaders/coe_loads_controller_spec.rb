require 'spec_helper'

describe Loaders::CoeLoadsController do
  # create non-coe loader user
  # create coe loader user
  # create load report
  # create image reports - one success, one error


  describe "GET #new" do

    it "redirects authed user not coe_loader" do
      #sign_in non-coe user
      #get :new
      #expect(response).to redirect_to(root_path)
    end

    it "redirects to sign in if unauthed user" do
      #get :new
      #expect(response).to redirect_to(new_user_session_path)
    end

    it "renders coe new if authed and coe_loader" do
      #sign_in coe loader user
      #expect(response).to render_template('loaders/new')
    end
  end

  describe "GET #show" do
    it "renders the 404 page for reports that don't exist" do
      # get :show, { id: '563445' }
      # expect(response).to render_template('error/404')
    end

    it "renders the show page for valid, authenticated requests" do
      # sign_in coe_loader
      # get :show, { id: load_report.id }
      # expect(response).to render_template('loaders/show')
    end

    it "redirects to sign in if unauthed user" do
      #get :new
      #expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects authed user not coe_loader" do
      #sign_in non-coe user
      #get :new
      #expect(response).to redirect_to(root_path)
    end
  end


  describe "GET #show_iptc" do
    it "renders the 404 page for image reports that don't exist" do
      # get :show, { id: '563445' }
      # expect(response).to render_template('error/404')
    end

    it "renders the show page for valid, authenticated requests" do
      # sign_in coe_loader
      # get :show, { id: image_report.id }
      # expect(response).to render_template('loaders/show')
    end

    it "redirects to sign in if unauthed user" do
      #get :new
      #expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects authed user not coe_loader" do
      #sign_in non-coe user
      #get :new
      #expect(response).to redirect_to(root_path)
    end
  end

  #destroy all load reports, image reports, users
end
