require 'spec_helper'

describe UploadAlert do
  

  describe "creation from core file" do  
    before :all do 
      @user = FactoryGirl.create(:bill) 
      @core = FactoryGirl.create(:bills_complete_file)

      @core.category =  "Theses and Dissertations" 
      @core.save!
    end

    after(:all) { @user.destroy ; @core.destroy } 

    def create_alert(change_type) 
      @alert = UploadAlert.create_from_core_file(@core, change_type) 
    end

    context "on core file creation" do 
      before(:each) { create_alert(:create) }

      it "has a title" do 
        @alert.title.should == @core.title 
      end

      it "has a category" do 
        @alert.depositor_email.should == @user.email 
      end

      it "has a full name" do 
        @alert.depositor_name.should == @user.full_name 
      end

      it "has a pid" do 
        @alert.pid.should == @core.pid 
      end

      it "has a content type" do 
        @alert.content_type.should == @core.category.first
      end

      it "has a change type" do 
        @alert.change_type.should == :create 
      end
    end

    context "on core file update" do 
      before(:each) { create_alert(:update) } 
      
      it "has a change type" do 
        @alert.change_type.should == :update
      end
    end

    context "with invalid change type" do 

      it "raises an error" do 
        expect{ UploadAlert.create_from_core_file(@core, 'edit') }.to raise_error 
      end

      it "raises an error" do 
        expect{ UploadAlert.create_from_core_file(@core, :edi) }.to raise_error 
      end
    end
  end
end