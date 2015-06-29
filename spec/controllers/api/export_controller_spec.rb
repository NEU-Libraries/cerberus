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
  end

  describe "GET #get_files" do
    it "gives an error with a non-valid starting ID" do
      @expected = {
        :error  => "A valid starting id is required"
      }.to_json
      get :get_files, :id => ""
      response.body.should == @expected
    end

    it "limits to the scope of the starting ID" do
      # TODO
    end

    it "doesn't provide embargoed items" do
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
