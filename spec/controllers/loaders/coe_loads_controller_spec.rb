require 'spec_helper'

describe Loaders::CoeLoadsController do
  let(:bill) { FactoryGirl.create(:bill) }
  let(:coe_loader) { FactoryGirl.create(:coe_loader) }
  render_views

  before :each do
    sign_in coe_loader
    @coe_col = Collection.create(pid: 'neu:5m60qz05t', title: 'COE Coll')
    @report_id = Loaders::LoadReport.create_from_strings(coe_loader, 0, "College of Engineering", @coe_col.pid)
  end

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
      assert_select "title", "College of Engineering Loader - DRS"
      assert_select "form[action=?]", "/loaders/coe" do
        assert_select "select[name=?]", "parent" do
          assert_select "option", "Select Collection"
        end
      end
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
      iptc = {:ImageDescription=>"April 9, 2015 - Scenes from the RISE:2015 expo and poster presentations held in Cabot Cage at Northeastern University on April 9, 2015. RISE (Research, Innovation and Scholarship Expo) is organized by the Center for Research Innovation and showcases student and faculty research at Northeastern University.", :Copyright=>"Copyright Northeastern University 2015", :"Province-State"=>"MA", :Keywords=>["innovation", "entrepreneurship", "venture", "research"], :"By-line"=>"Canaday, Brooks", :"By-lineTitle"=>"Staff Photographer", :Format=>"image/jpeg"}
      @core_file = CoreFile.create(title: "Test COE", parent: @coe_col, depositor: coe_loader.nuid)
      @item_report = @load_report.item_reports.create_success(@core_file, iptc)
    end

    it "renders the 404 page for image reports that don't exist" do
      get :show_iptc, { id: '563445' }
      expect(response).to render_template('error/404')
    end

    it "renders the show page for valid, authenticated requests" do
      features_sign_in coe_loader

      get :show_iptc, { id: @item_report.id }
      expect(response).to render_template('loaders/iptc')
      assert_select "td", "By-line"
      assert_select "td", "Canaday, Brooks"
      assert_select "td", "April 9, 2015 - Scenes from the RISE:2015 expo and poster presentations held in Cabot Cage at Northeastern University on April 9, 2015. RISE (Research, Innovation and Scholarship Expo) is organized by the Center for Research Innovation and showcases student and faculty research at Northeastern University."
      assert_select "td", "Copyright Northeastern University 2015"
      assert_select "td", "MA"
      assert_select "td", "Staff Photographer"
      assert_select "td", "image/jpeg"
    end

    it "redirects to sign in if unauthed user" do
      sign_out coe_loader
      get :show_iptc, { id: @item_report.id}
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects authed user not coe_loader" do
      sign_in bill
      get :show_iptc, { id: @item_report.id}
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
  end

  after :each do
    Loaders::LoadReport.find(@report_id).destroy
    @coe_col.destroy if @coe_col
    CoreFile.all.map { |x| x.destroy }
    Loaders::ItemReport.all.each do |ir|
      ir.destroy
    end
  end

end
