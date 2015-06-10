require 'spec_helper'

describe Api::V1::CoreFilesController, :type => :controller do

  let(:private_file) { FactoryGirl.create(:bills_private_file) }
  let(:embargoed_file) { FactoryGirl.create(:bills_embargoed_file)}
  let(:incomplete_file) { FactoryGirl.create(:bills_incomplete_file)}
  let(:in_progress_file) { FactoryGirl.create(:bills_in_progress_file)}
  let(:complete_file) { FactoryGirl.create(:bills_complete_file)}

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
      get :show, :id => private_file.pid
      response.body.should == @expected
    end

    it "gives an error if the file is embargoed" do
      @expected = {
        :error  => "The item you've requested is unavailable."
      }.to_json
      get :show, :id => embargoed_file.pid
      response.body.should == @expected
    end

    it "gives an error if the file is incomplete" do
      @expected = {
        :error  => "The item you've requested is unavailable."
      }.to_json
      get :show, :id => incomplete_file.pid
      response.body.should == @expected
    end

    it "gives an error if the file is in progress" do
      @expected = {
        :error  => "The item you've requested is unavailable."
      }.to_json
      get :show, :id => in_progress_file.pid
      response.body.should == @expected
    end

    it "responds with correct JSON for a complete file" do
      get :show, :id => complete_file.pid
      response.body.should == complete_file.to_hash.to_json
    end
  end

end
