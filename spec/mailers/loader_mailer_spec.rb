require "spec_helper"
describe LoaderMailer do

  describe "load_alert" do
    before :each do
      FactoryGirl.create_list(:marcom_load)
    end

    let(:mail) { LoaderMailer.load_alert }

    it "purges sent emails" do
      Loaders::LoadReport.all.size.should == 2
      mail
      Loaders::LoadReport.all.find_all.size.should == 0
    end

    it "should have a subject with a correct item count" do
      mail.deliver!
      ActionMailer::Base.deliveries.first.subject.should == "Daily digest of XML edits - 2 items"
    end

  end
end
