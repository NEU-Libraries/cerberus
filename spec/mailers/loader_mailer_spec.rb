require "spec_helper"
describe LoaderMailer do

  describe "load_alert" do
    before :each do
      FactoryGirl.create_list(:marcom_load)
    end

    let(:mail) { LoaderMailer.load_alert }

    it "should send mail" do
      #sends mail?
    end
    #after delete list?
  end
end
