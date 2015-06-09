require 'spec_helper'

describe Api::V1::CoreFilesController, :type => :controller do

  let(:file) { FactoryGirl.create(:bills_private_file) }

  describe "GET #show" do
    it "gives an error indicating if no id given" do
      @expected = {
        :error  => "An id is required for this action."
      }.to_json
      get :show, :id => ""
      response.body.should == @expected
    end

    it "gives an error if the file isn't public" do
      @expected = {
        :error  => "The item you've requested is unavailable."
      }.to_json
      get :show, :id => file.pid
      response.body.should == @expected
    end

    it "gives an error if the file is embargoed" do
    end
  end

end
