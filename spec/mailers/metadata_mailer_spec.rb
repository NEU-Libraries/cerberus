require "spec_helper"

describe MetadataMailer do

  describe "daily_alert_email" do
    before :each do
      FactoryGirl.create_list(:theses_alert, 2)
    end

    let(:mail) { MetadataMailer.daily_alert_email }

    it "purges sent emails" do
      UploadAlert.withheld_theses(:create).size.should == 2
      mail
      UploadAlert.withheld_theses(:create).size.should == 0
    end

    it "should have a subject with a correct item count" do
      mail.deliver!
      ActionMailer::Base.deliveries.first.subject.should == "Daily Featured Content Uploads and Updates - 2 items"
    end

  end

  describe "daily_nonfeatured_alert_email" do
    before :each do
      FactoryGirl.create_list(:collection_alert, 2)
    end
    let(:mail){MetadataMailer.daily_nonfeatured_alert_email}

    it "purges sent emails" do
      UploadAlert.withheld_collections(:create).size.should == 2
      mail
      UploadAlert.withheld_collections(:create).size.should == 0
    end

    it "should have a subject with a correct item count" do
      mail.deliver!
      ActionMailer::Base.deliveries.first.subject.should == "Daily Non-Featured Content and Collection Uploads and Updates - 2 items"
    end

  end
end
