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

    it "assigns the title correctly" do 
      @thumb.title.should == @image.title + " thumbnail" 
    end

    it "labels the content datastream correctly" do 
      @thumb.content.label.should be_thumby_label_for @image
    end
  end

  describe "on pdfs" do 
    before :all do 
      @pdf = FactoryGirl.create(:pdf_file) 
      @core = @pdf.core_record 
      AtomisticCharacterizationJob.new(@pdf.pid).run 
      @thumb = @pdf.core_record.content_objects.find { |e| e.instance_of? ImageThumbnailFile } 
    end

    after :all do 
      ActiveFedora::Base.destroy_all 
    end

    it "labels the content datastream correctly" do 
      @thumb.content.label.should be_thumby_label_for @pdf 
    end

    it "assigns content to the content datastream of the thumb" do 
      @thumb.content.content.should_not be nil 
    end
  end
end