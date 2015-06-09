require 'spec_helper'

describe Api::V1::CoreFilesController, :type => :controller do

  describe "GET #show" do
    it "provides an error indicating that an id is required" do
      # get api_v1_search_path(id: "")
      get :show, :id => ""
      response.body.should == "derp"
    end
  end

end
