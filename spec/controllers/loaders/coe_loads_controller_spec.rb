require 'spec_helper'

describe Loaders::CoeLoadsController do
  let(:bill) { FactoryGirl.create(:bill) }
  let(:coe_loader) { FactoryGirl.create(:coe_loader) }
  # let(:@coe_col) { FactoryGirl.create(:@coe_col) }
  before :each do
    sign_in coe_loader
    @coe_col = Collection.create(pid: 'neu:5m60qz05t', title: 'COE Coll')
    @report_id = Loaders::LoadReport.create_from_strings(coe_loader, 0, "College of Engineering", @coe_col.pid)

  end
  # let(:coe_comm) { FactoryGirl.create(:coe_comm) }
  # create fake collection
  # create load report
  # create image reports - one success, one error
  describe "GET #new" do
    it "redirects authed user not coe_loader" do
      sign_in bill
      get :new
      expect(response).to redirect_to(root_path)
    end

    it "redirects to sign in if unauthed user" do
      sign_out coe_loader
      get :new
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders coe new if authed and coe_loader" do
      get :new
      expect(response).to render_template('loaders/new')
      # should have correct page title
      # #should have correct array of child collections
    end
  end

  describe "GET #show" do
    it "renders the 404 page for reports that don't exist" do
      get :show, { id: '563445' }
      expect(response).to render_template('error/404')
    end

    it "renders the show page for valid, authenticated requests" do
      get :show, { id: @report_id }
      expect(response).to render_template('loaders/show')
    end

    it "redirects to sign in if unauthed user" do
      sign_out coe_loader
      get :show, { id: @report_id}
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects authed user not coe_loader" do
      sign_in bill
      get :show, { id: @report_id }
      expect(response).to redirect_to(root_path)
    end
  end


  describe "GET #show_iptc" do
    before :each do
      @load_report = Loaders::LoadReport.find(@report_id)
      iptc = {:ImageDescription=>"April 9, 2015 - Scenes from the RISE:2015 expo and poster presentations held in Cabot Cage at Northeastern University on April 9, 2015. RISE (Research, Innovation and Scholarship Expo) is organized by the Center for Research Innovation and showcases student and faculty research at Northeastern University.", :Copyright=>"Copyright Northeastern University 2015", :"Province-State"=>"MA", :Keywords=>["innovation", "entrepreneurship", "venture", "research"], :"By-line"=>"Canaday, Brooks", :"By-lineTitle"=>"Staff Photographer", :"Caption-Abstract"=>"April 9, 2015 - Isabel Brostella discussed \"Applications for Sandbag Construction Method\" at the RISE:2015 expo and poster presentations held in Cabot Cage at Northeastern University on April 9, 2015. RISE (Research, Innovation and Scholarship Expo) is organized by the Center for Research Innovation and showcases student and faculty research at Northeastern University.", :Format=>"image/jpeg", :Subject=>["innovation", "entrepreneurship", "venture", "research"]}
      @core_file = CoreFile.create(title: "Test COE", parent: @coe_col, depositor: coe_loader.nuid)
      @image_report = @load_report.image_reports.create_success(@core_file, iptc)
    end

    it "renders the 404 page for image reports that don't exist" do
      get :show_iptc, { id: '563445' }
      expect(response).to render_template('error/404')
    end

    it "renders the show page for valid, authenticated requests" do
      get :show_iptc, { id: @image_report.id }
      expect(response).to render_template('loaders/iptc')
      #check iptc data
    end

    it "redirects to sign in if unauthed user" do
      sign_out coe_loader
      get :show_iptc, { id: @image_report.id}
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects authed user not coe_loader" do
      sign_in bill
      get :show_iptc, { id: @image_report.id}
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST #create" do
    it "requests signin from unauthenticated users" do
      sign_out coe_loader
      post :create, {}
      expect(response).to redirect_to(new_user_session_path)
    end

    it "403s when users attempt to create without the right group" do
      sign_in bill
      post :create, { parent: @coe_col.id }
      expect(response).to redirect_to(root_path)
    end

    it "creates load report on creation" do
      #post :create, {parent: @coe_col.id, file: "#{Rails.root}/spec/fixtures/files/marcom.jpg"}
      #need to pass a zip in and redirect to my_loaders afterwards
    end
  end

  after :each do
    Loaders::LoadReport.find(@report_id).destroy
    @coe_col.destroy if @coe_col
    @core_file.destroy if @core_file
    @image_report.destroy if @image_report
  end

end
