require 'spec_helper'

describe CommunitiesController do
  render_views

  before :each do
    @root_community = FactoryGirl.create(:root_community)
    @bill = FactoryGirl.create(:bill)
    @bills_collection = Collection.create(parent: @root_community.pid, depositor: @bill.nuid, mass_permissions: "public")
  end

  after :each do
    ActiveFedora::Base.destroy_all
  end

  describe "GET #show" do
    it "renders the show template for unauthed users on public collections" do

      get :show, { id: @root_community.pid }

      expect(response).to render_template('shared/sets/show')
    end
  end

  describe "GET #recent_deposits" do

    it "should redirect to collection if no core_files" do
      get :recent_deposits, { id: @root_community.pid }

      expect(response).to redirect_to(community_path(id: @root_community.pid))
    end

    it "should have docs if there are core_files" do
      sign_in @bill
      cf = CoreFile.create(title: "Bills Core", parent: @bills_collection, mass_permissions: "public", depositor: @bill.nuid)
      get :recent_deposits, { id: @root_community.pid }
      expected = "/communities/#{@root_community.pid}/recent"
      request.path.should == expected
      response.body.should =~ /Bills Core/m
      response.body.should =~ /Recent Deposits/m
    end

    it "should respond with rss when asked for it" do
      sign_in @bill
      cf = CoreFile.create(title: "Bills Core", parent: @bills_collection, mass_permissions: "public", depositor: @bill.nuid)
      get :recent_deposits, { id: @root_community.pid, format: "rss" }
      response.body.should =~ /rss/m
      response.body.should =~ /<item>/m
    end

    it "should not return items which are not public" do
      sign_in @bill
      cf = CoreFile.create(title: "Bills Core", parent: @bills_collection, mass_permissions: "private", depositor: @bill.nuid)
      get :recent_deposits, { id: @root_community.pid, format: "rss" }
      response.body.should =~ /rss/m
      response.body.should_not =~ /<item>/m
    end

    it "should not return items which are incomplete or in progress" do
      get :recent_deposits, { id: @root_community.pid, format: "rss" }
      response.body.should =~ /rss/m
      response.body.should_not =~ /<item>/m
    end

    it "should not return items which are embargoed" do
      get :recent_deposits, { id: @root_community.pid, format: "rss" }
      response.body.should =~ /rss/m
      response.body.should_not =~ /<item>/m
    end
  end
end
