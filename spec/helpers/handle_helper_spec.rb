require "spec_helper"
include HandleHelper
ENV["HANDLE_HOST"] = "localhost"
ENV["HANDLE_USERNAME"] = "root"
ENV["HANDLE_PASSWORD"] = ""
ENV["HANDLE_DATABASE"] = "handles_test"

describe HandleHelper do
  let(:bills_file) { FactoryGirl.create(:bills_complete_file) }
  before :all do
    `mysql -u "#{ENV["HANDLE_USERNAME"]}" < "#{Rails.root}"/spec/fixtures/files/handlesTEST.sql`
    @client = Mysql2::Client.new(:host => "#{ENV["HANDLE_HOST"]}", :username => "#{ENV["HANDLE_USERNAME"]}", :password => "#{ENV["HANDLE_PASSWORD"]}", :database => "#{ENV["HANDLE_DATABASE"]}")
  end

  it "makes a handle" do
    make_handle(bills_file.persistent_url, @client).should == "http://hdl.handle.net/2047/D10000001"
    handle_exists?(bills_file.persistent_url, @client).should == true
    retrieve_handle(bills_file.persistent_url, @client).should == "http://hdl.handle.net/2047/D10000001"
  end

  after :all do
    @client.query("TRUNCATE TABLE handles_test.handles;")
  end
end
