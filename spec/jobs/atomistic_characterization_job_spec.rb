require 'spec_helper'

describe AtomisticCharacterizationJob do

  def context_for_thumbnail_tests(factory_sym)
    @master = FactoryGirl.create(factory_sym) 
    @core = @master.core_record 
    AtomisticCharacterizationJob.new(@master.pid).run 
    @thumb = @core.content_objects.find { |e| e.instance_of? ImageThumbnailFile } 
  end

  def context_for_prethumbed_test(factory_sym) 
    @master = FactoryGirl.create(factory_sym) 
    @core = @master.core_record 
    @thumb_alpha = FactoryGirl.create(:previous_thumbnail_file)
    @thumb_alpha.core_record = NuCoreFile.find(@core.pid) 
    @thumb_alpha.save! 
  end

  def context_for_msword_test 
    @master = FactoryGirl.create(:docx_file) 
    @core = @master.core_record 
    AtomisticCharacterizationJob.new(@master.pid).run 
    @pdf = @core.content_objects.find { |e| e.instance_of? PdfFile } 
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

    it "assigns the identifier correctly" do
      @thumb.identifier.should_not be_blank 
      @thumb.identifier.should == @thumb.pid  
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

  describe "On Msword files" do 
    before(:all) { context_for_msword_test } 
    after(:all) { ActiveFedora::Base.destroy_all }

    it "creates one (and only one) pdf file" do 
      count = @core.content_objects.count { |e| e.instance_of? PdfFile } 
      count.should be 1 
    end

    it "titles the PDF file appropriately" do 
      @pdf.title.should == "#{@master.title} pdf" 
    end

    it "assigns content to the PDF file" do 
      @pdf.content.content.should_not be nil 
    end

    it "assigns the depositor" do 
      @pdf.depositor.should == @master.depositor 
    end

    it "has equivalent permissions" do 
      @pdf.rightsMetadata.content.should == @master.rightsMetadata.content
    end

    it "assigns all keywords" do 
      @pdf.keywords.should =~ @master.keywords
    end

    it "correctly labels the file" do 
      @pdf.content.label.should == 'test_docx.pdf' 
    end

    it "assigns identifier for the pdf" do 
      @pdf.identifier.should_not be_blank 
      @pdf.identifier.should == @pdf.pid 
    end

    it_should_behave_like "a content object that creates a thumbnail"
  end


  describe "with an already extant thumbnail" do 
    before(:all) do 
      context_for_prethumbed_test(:image_master_file)
      AtomisticCharacterizationJob.new(@master.pid).run

      # Refresh all objects after the job messes with them
      @master.reload
      @core.reload
      @thumb_omega = @core.content_objects.find { |c| c.instance_of? ImageThumbnailFile }
    end

    let(:previous) { FactoryGirl.build(:previous_thumbnail_file) } 

    after(:all) { ActiveFedora::Base.destroy_all }

    it "destroys the first thumbnail" do 
      ImageThumbnailFile.exists?(@thumb_alpha.pid).should be false 
    end

    it "updates relevant metadata" do 
      @thumb_omega.title.should == @master.title + " thumbnail" 
      @thumb_omega.keywords.should =~ @master.keywords  
    end

    it "labels the content datastream correctly" do 
      @thumb_omega.content.label.should be_thumby_label_for @master 
    end

    it "has new content" do 
      @thumb_omega.content.content.should_not == previous.content.content
    end
  end
end