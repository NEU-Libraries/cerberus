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


  end
end
