require "spec_helper"
include HandleHelper

describe HandleHelper do
  let(:bills_file) { FactoryGirl.create(:bills_complete_file) }
  before :all do
    `mysql -u "#{ENV["HANDLE_TEST_USERNAME"]}" < "#{Rails.root}"/spec/fixtures/files/handlesTEST.sql`
    @client = Mysql2::Client.new(:host => "#{ENV["HANDLE_TEST_HOST"]}", :username => "#{ENV["HANDLE_TEST_USERNAME"]}", :password => "#{ENV["HANDLE_TEST_PASSWORD"]}", :database => "#{ENV["HANDLE_TEST_DATABASE"]}")
  end

  it "makes a handle" do
    make_handle(bills_file.persistent_url, @client).should == "http://hdl.handle.net/2047/D10000001"
    handle_exists?(bills_file.persistent_url, @client).should == true
    retrieve_handle(bills_file.persistent_url, @client).should == "http://hdl.handle.net/2047/D10000001"
  end

  after :all do
    @client.query("DROP DATABASE #{ENV["HANDLE_TEST_DATABASE"]};")
  end
end
