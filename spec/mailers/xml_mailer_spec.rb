require "spec_helper"
describe XmlMailer do

  describe "daily_alert_email" do
    before :each do
      FactoryGirl.create_list(:xml_alert, 2)
    end

    let(:mail) { XmlMailer.daily_alert_email }

    it "purges sent emails" do
      XmlAlert.where('notified = ?', false).find_all.size.should == 2
      mail
      XmlAlert.where('notified = ?', false).find_all.size.should == 0
    end

    it "should have a subject with a correct item count" do
      mail.deliver!
      ActionMailer::Base.deliveries.first.subject.should == "Daily digest of XML edits - 2 items"
    end

  end
end
