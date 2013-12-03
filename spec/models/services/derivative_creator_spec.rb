require 'spec_helper'

describe DerivativeCreator do

  describe "image thumbnail creation" do 
    before :all do 
      @img = FactoryGirl.create(:image_master_file) 
      @img.characterize # required for the DerivativeCreator method to work
      DerivativeCreator.new(@img.pid).generate_derivatives 
      @thumb = @img.core_record.thumbnail 
    end

    after(:all) { @img.core_record.destroy } 

    it "creates a thumbnail" do 
      @thumb.should be_an_instance_of(ImageThumbnailFile) 
    end

    # For context, the original image has a height of 195 and a width of 259
    it "generates those thumbnails that do not require scaling up" do 
      @thumb.thumbnail_1.content.should_not be nil 
      @thumb.thumbnail_2.content.should_not be nil 
    end

    it "doesn't generate those thumbnails that would require scaling up" do 
      @thumb.thumbnail_2_2x.content.should be nil 
      @thumb.thumbnail_4.content.should be nil 
      @thumb.thumbnail_4_2x.content.should be nil 
      @thumb.thumbnail_10.content.should be nil 
      @thumb.thumbnail_10_2x.content.should be nil 
    end
  end

  describe "pdf thumbnail creator" do 
    before :all do 
      @pdf = FactoryGirl.create(:pdf_file) 
      @pdf.characterize 
      DerivativeCreator.new(@pdf.pid).generate_derivatives 
      @thumb = @pdf.core_record.thumbnail 
    end

    it "creates a thumbnail" do 
      @thumb.should be_an_instance_of(ImageThumbnailFile) 
    end

    it "generates a selected set of thumbnails" do 
      @thumb.thumbnail_1.content.should_not be nil 
      @thumb.thumbnail_2.content.should_not be nil 
      @thumb.thumbnail_2_2x.content.should_not be nil 
      @thumb.thumbnail_4.content.should_not be nil 
      @thumb.thumbnail_4_2x.content.should_not be nil 
    end
  end

  describe "msword thumbnail and pdf creator" do 
    before :all do 
      @word = FactoryGirl.create(:docx_file) 
      @word.characterize 
      DerivativeCreator.new(@word.pid).generate_derivatives
      @pdf = @word.core_record.content_objects.find { |e| e.instance_of? PdfFile } 
      @thumb = @word.core_record.thumbnail 
    end

    it "creates a thumbnail" do 
      @thumb.should be_an_instance_of(ImageThumbnailFile)
    end

    it "creates only one pdf file" do 
      count = @word.core_record.content_objects.count { |c| c.instance_of? PdfFile } 
      count.should be == 1 
    end 

    it "populates the content of the pdf file" do 
      @pdf.content.should_not be nil 
    end

    it "generates a selected set of thumbnails" do 
      @thumb.thumbnail_1.content.should_not be nil 
      @thumb.thumbnail_2.content.should_not be nil 
      @thumb.thumbnail_2_2x.content.should_not be nil 
      @thumb.thumbnail_4.content.should_not be nil 
      @thumb.thumbnail_4_2x.content.should_not be nil 
    end
  end
end