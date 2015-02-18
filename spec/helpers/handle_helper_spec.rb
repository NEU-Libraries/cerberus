require "spec_helper"

describe HandleHelper do

  before :all do
    sh "mysql -u #{ENV["HANDLE_TEST_USERNAME"]} -p#{ENV["HANDLE_TEST_PASSWORD"]} < #{Rails.root}/spec/fixtures/files/handlesTEST.sql"
    client = Mysql2::Client.new(:host => "#{ENV["HANDLE_TEST_HOST"]}",
      :username => "#{ENV["HANDLE_TEST_USERNAME"]}",
      :password => "#{ENV["HANDLE_TEST_PASSWORD"]}",
      :database => "#{ENV["HANDLE_TEST_DATABASE"]}")
  end

  after :all do
    client.query("DROP DATABASE #{ENV["HANDLE_TEST_DATABASE"]};")
  end
end
