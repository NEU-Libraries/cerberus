require "spec_helper"
include UrlHelper

describe UrlHelper do

  it "convers url links to a tags" do
    string = "Hello world http://www.google.com"
    convert_urls(string).should == "Hello world <a href='http://www.google.com' target='_blank'>http://www.google.com</a>"
  end

end
