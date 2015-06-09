require 'spec_helper'

describe Api::V1::CoreFilesController, :type => :controller do

  describe "GET #show" do
    it "provides an error indicating that an id is required" do
      @expected = {
        :error  => "An id is required for this action."
      }.to_json
      get :show, :id => ""
      response.body.should == @expected
    end
  end

end
