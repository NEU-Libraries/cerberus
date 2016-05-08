require 'spec_helper'

describe Api::V1::ExportController, :type => :controller do

  before(:all) do
    @root = Collection.create(title: "Root", mass_permissions: "public")
    @other_collection = Collection.create(title: "Other collection", mass_permissions: "public")
    @private_collection = Collection.create(title: "Other collection", mass_permissions: "private")
    @child_one = Collection.create(title: "Child One", parent: @root, mass_permissions: "public")
    @c1_gf = CoreFile.create(title: "Core File One", parent: @child_one, depositor: "0", mass_permissions: "public")
    @c2_gf = CoreFile.create(title: "Core File Two", parent: @child_one, depositor: "0", mass_permissions: "public")
    @child_two = Collection.create(title: "Child Two", parent: @root, mass_permissions: "public")
    @grandchild = Collection.create(title: "Grandchild", parent: @child_two, mass_permissions: "public")
    @great_grandchild = Collection.create(title: "Great Grandchild", parent: @grandchild)
    @gg_cf = CoreFile.create(title: "GG CF", parent: @great_grandchild, depositor: "0", mass_permissions: "public")
    @out_of_scope_cf = CoreFile.create(title: "Out of scope", parent: @other_collection, depositor: "0", mass_permissions: "public")
    @embargoed = CoreFile.create(title: "Embargo Test", parent: @child_one, depositor: "0", mass_permissions: "public", embargo_release_date: Date.tomorrow.to_s)
  end

  after(:all) do
    ActiveFedora::Base.destroy_all
  end

  describe "GET #get_files" do
<<<<<<< Updated upstream
    it "gives an error with a invalid starting ID" do
      @expected = {
        :error  => "A valid starting ID is required"
      }.to_json
      get :get_files, :id => ""
      response.body.should == @expected
    end

    it "gives an error if the ID class isn't a Collection or Compilation" do
      @expected = {
        :error  => "ID must match either a Collection or a Set"
      }.to_json
      get :get_files, :id => @c1_gf.pid
      response.body.should == @expected
    end

    it "gives an error if the starting ID is for an obj that isn't public" do
      @expected = {
        :error  => "ID must be for a public item"
      }.to_json
      get :get_files, :id => @private_collection.pid
      response.body.should == @expected
    end

    it "limits to the scope of the starting ID" do
      get :get_files, :id => @root.pid
      res = JSON.parse(response.body)
      res["pagination"]["table"]["total_count"].should == 3
    end

    it "doesn't provide embargoed items" do
      get :get_files, :id => @root.pid
      res = JSON.parse(response.body)
      res["pagination"]["table"]["total_count"].should == 3 # no pagination allows for the following checks to be true

      items = res["items"]
      embargoed_found = false
      items.each do |key, item|
        if item["pid"][0] == @embargoed.pid
          embargoed_found = true
        end
      end
      embargoed_found.should == false
    end

    it "doesn't provide in progress items" do
      #TODO
    end

    it "doesn't provide incomplete items" do
      #TODO
    end

    it "doesn't provide private items" do
      #TODO
    end

    it "only shows public items" do
      #TODO
    end

    it "only shows Core File objects" do
      #TODO
    end

    it "has working pagination" do
      #TODO
    end

    it "works with compilations" do
      #TODO
=======
    it "limits scope" do
    end

    it "only retrieves core_files" do
    end

    it "only retrieves public obejcts" do
    end

    it "doesn't return embargoed objects" do
    end

    it "doesn't return in progress objects" do
>>>>>>> Stashed changes
    end

    it "doesn't return incomplete objects" do
    end

    it "includes pagination in the JSON" do
    end

    it "prevents the user from going to a page that doesn't exist" do
    end

    it "doesn't allow an invalid starting id" do
    end
  end
end
