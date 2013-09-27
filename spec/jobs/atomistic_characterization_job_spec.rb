require 'spec_helper'

describe AtomisticCharacterizationJob do

  def context_for_thumbnail_tests(factory_sym)
    @master = FactoryGirl.create(factory_sym) 
    @core = @master.core_record 
    AtomisticCharacterizationJob.new(@master.pid).run 
    @thumb = @core.content_objects.find { |e| e.instance_of? ImageThumbnailFile } 
  end

  shared_examples_for "a content object that creates a thumbnail" do 
    it "builds one and only one thumbnail" do 
      thumbs = @core.content_objects.count { |o| o.instance_of? ImageThumbnailFile }

      thumbs.should be 1
    end

    it "assigns keywords correctly" do
      @thumb.keywords.should =~ @master.keywords 
    end 

    it "assigns description correctly" do 
      @thumb.description.should == "Thumbnail for #{@master.pid}" 
    end

    it "mirrors the permissions of the creating object" do 
      @thumb.permissions.should == @master.permissions 
    end

    it "assigns content to the content datastream of the thumb" do 
      @thumb.content.content.should_not be nil 
    end

    it "assigns the title correctly" do 
      @thumb.title.should == @master.title + " thumbnail" 
    end

    it "labels the content datastream correctly" do 
      @thumb.content.label.should be_thumby_label_for @master
    end
  end    


  describe "on images" do
    it_should_behave_like "a content object that creates a thumbnail" do 
      before(:all) { context_for_thumbnail_tests(:image_master_file) } 
      after(:all)  { ActiveFedora::Base.destroy_all } 
    end
  end

  describe "on pdfs" do 
    it_should_behave_like "a content object that creates a thumbnail" do 
      before(:all) { context_for_thumbnail_tests(:pdf_file) } 
      after(:all)  { ActiveFedora::Base.destroy_all } 
    end
  end
end