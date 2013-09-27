require 'spec_helper'

describe AtomisticCharacterizationJob do

  describe "on images" do 

    before :all do
      @image = FactoryGirl.create(:image_master_file)
      @core = @image.core_record 
      a = AtomisticCharacterizationJob.new(@image.pid).run
      @thumb = @image.core_record.content_objects.find { |e| e.instance_of? ImageThumbnailFile } 
    end

    after :all do 
      ActiveFedora::Base.destroy_all 
    end

    it "builds one and only one thumbnail" do 
      thumbs = @core.content_objects.count { |o| o.instance_of? ImageThumbnailFile }

      thumbs.should be 1
    end

    it "assigns keywords correctly" do
      @thumb.keywords.should =~ @image.keywords 
    end 

    it "assigns description correctly" do 
      @thumb.description.should == "Thumbnail for #{@image.pid}" 
    end

    it "mirrors the permissions of the creating object" do 
      @thumb.permissions.should == @image.permissions 
    end

    it "assigns content to the content datastream of the thumb" do 
      @thumb.content.content.should_not be nil 
    end
    
    pending "write custom matcher for thumby titles"
  end 
end