require 'spec_helper'

describe Api::V1::ExportController, :type => :controller do

  before(:all) do
    @root = Collection.create(title: "Root", mass_permissions: "public")
    @other_collection = Collection.create(title: "Other collection", mass_permissions: "public")
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

  describe "GET #get_files" do
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
    end

    it "doesn't provide incomplete items" do
    end

    it "doesn't provide private items" do
    end

    it "only shows public items" do
    end

    it "only shows Core File objects" do
    end

    it "has working pagination" do
    end

    it "works with compilations" do
      #TODO - implement
    end
  end

end
