require 'spec_helper' 

describe Drs::Content::Transformations do 
  let(:imf) { FactoryGirl.create(:image_master_file) } 
  let(:pdf) { FactoryGirl.create(:pdf_file) } 
  let(:doc) { FactoryGirl.create(:docx_file) }

  shared_examples_for "a thumbnail generating transformation" do 
    it "builds one and only one thumbnail" do 
      thumbs = @core.content_objects.count { |o| o.instance_of? ImageThumbnailFile }

      thumbs.should be 1
    end

    it "assigns keywords correctly" do
      @thumb.keywords.should =~ @master.keywords 
    end

    it "assigns the core record correctly" do 
      @thumb.core_record.should == @master.core_record
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


  describe "of images to thumbnails" do 
    it_should_behave_like 'a thumbnail generating transformation' do 
      before :all do 
        @master = FactoryGirl.create(:image_master_file) 
        @core = @master.core_record 
        @thumb = Drs::Content::Transformations.image_to_thumbnail(@master) 
      end

      after(:all) { ActiveFedora::Base.destroy_all } 
    end
  end

  describe "of pdfs to thumbnails" do
    it_should_behave_like 'a thumbnail generating transformation' do 
      before :all do 
        @master = FactoryGirl.create(:pdf_file) 
        @core = @master.core_record 
        @thumb = Drs::Content::Transformations.pdf_to_thumbnail(@master) 
      end

      after(:all) { ActiveFedora::Base.destroy_all } 
    end

  end

  describe "of docx documents to pdfs" do 

  end
end