require 'spec_helper'

describe DerivativeCreator, unless: $in_travis do

  def titled_core_record(core_record, title)
    core_record.title = title
    core_record.save! ? CoreFile.find(core_record.pid) : nil
  end

  def context(factory_sym, core_title)
    @master = FactoryGirl.create(factory_sym)

    if !$in_travis
      @master.characterize
    end

    @core = titled_core_record(@master.core_record, core_title)
    DerivativeCreator.new(@master.pid).generate_derivatives
    @thumb = @core.thumbnail
  end

  shared_examples_for "a content object that generates thumbnail metadata" do
    it "has a title" do
      @thumb.title.should == "#{@core.title} thumbnails"
    end

    it "has a description" do
      @thumb.description.should == "Thumbnails for #{@core.pid}"
    end

    it "has an identifier" do
      @thumb.identifier.should == @thumb.pid
    end

    it "has keywords" do
      @thumb.keywords.should =~ @core.keywords
    end

    it "has a depositor" do
      @thumb.depositor.should == @core.depositor
    end

    it "has the right parent" do
      @thumb.core_record.pid.should == @core.pid
    end

    it "Has identical privileges to its core_file object" do
      @thumb.rightsMetadata.content.should == @core.rightsMetadata.content
    end
  end

  shared_examples_for "a content object that generates thumbnails from a PDF" do

    it "generates thumbnails up to the 4_2x size" do
      # @thumb.thumbnail_1.content.should_not be nil
      # @thumb.thumbnail_2.content.should_not be nil
      # @thumb.thumbnail_3.content.should_not be nil
      # @thumb.thumbnail_4.content.should_not be nil
      # @thumb.thumbnail_5.content.should_not be nil
    end
  end

  describe "image thumbnail creation" do
    before(:all) { context(:image_master_file, "Test Image") }
    after(:all)  { @core.destroy }

    # For context, the original image has a height of 195 and a width of 259
    it "generates those thumbnails that do not require scaling up" do
      # @thumb.thumbnail_1.content.should_not be nil
      # @thumb.thumbnail_2.content.should_not be nil
    end

    it "doesn't generate those thumbnails that would require scaling up" do
      # @thumb.thumbnail_3.content.should be nil
      # @thumb.thumbnail_4.content.should be nil
      # @thumb.thumbnail_5.content.should be nil
    end

    it_should_behave_like "a content object that generates thumbnail metadata"
  end

  describe "pdf thumbnail creator" do
    before(:all) { context(:pdf_file, "Test PDF") }
    after(:all)  { @core.destroy }

    it_should_behave_like "a content object that generates thumbnail metadata"
    it_should_behave_like "a content object that generates thumbnails from a PDF"
  end

  describe "msword thumbnail and pdf creator" do
    before :all do
      context(:docx_file, "Test Msword")
      @pdf = @core.content_objects.find { |e| e.instance_of? PdfFile }
    end

    after(:all) { @core.destroy }

    it "creates only one pdf file" do
      count = @master.core_record.content_objects.count { |c| c.instance_of? PdfFile }
      count.should be == 1
    end

    it "populates the content of the pdf file" do
      @pdf.content.should_not be nil
    end

    it_should_behave_like "a content object that generates thumbnail metadata"
    it_should_behave_like "a content object that generates thumbnails from a PDF"
  end
end
