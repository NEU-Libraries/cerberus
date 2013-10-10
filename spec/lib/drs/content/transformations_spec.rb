require 'spec_helper' 

describe Drs::Content::Transformations do 

  def transform_context(factory_type, transformation) 
    @master = FactoryGirl.create(factory_type) 
    @core   = @master.core_record 
    @deriv  = Drs::Content::Transformations.send(transformation, @master)  
  end 

  shared_examples_for "a thumbnail generating transformation" do 
    it "builds one and only one thumbnail" do 
      thumbs = @core.content_objects.count { |o| o.instance_of? ImageThumbnailFile }

      thumbs.should be 1
    end

    it "assigns keywords correctly" do
      @deriv.keywords.should =~ @master.keywords 
    end

    it "assigns the core record correctly" do 
      @deriv.core_record.should == @master.core_record
    end

    it "assigns description correctly" do 
      @deriv.description.should == "Thumbnail for #{@master.pid}" 
    end

    it "mirrors the permissions of the creating object" do 
      @deriv.permissions.should == @master.permissions 
    end

    it "assigns content to the content datastream of the thumb" do 
      @deriv.content.content.should_not be nil 
    end

    it "assigns the title correctly" do 
      @deriv.title.should == @master.title + " thumbnail" 
    end

    it "labels the content datastream correctly" do 
      @deriv.content.label.should be_thumby_label_for @master
    end

    it "assigns the identifier correctly" do
      @deriv.identifier.should_not be_blank 
      @deriv.identifier.should == @deriv.pid  
    end
  end 

  describe "of images to thumbnails" do 
    it_should_behave_like 'a thumbnail generating transformation' do
      before(:all) { transform_context(:image_master_file, :image_to_thumbnail) } 
      after(:all)  { @core.destroy } 
    end
  end

  describe "of pdfs to thumbnails" do
    it_should_behave_like 'a thumbnail generating transformation' do
      before(:all) { transform_context(:pdf_file, :pdf_to_thumbnail) } 
      after(:all)  { @core.destroy } 
    end
  end

  describe "of word documents to pdfs" do 
    before(:all) { transform_context(:docx_file, :word_to_pdf) }
    after(:all)  { @core.destroy } 

    it "creates one and only one PdfFile" do 
      count = @core.content_objects.count { |c| c.instance_of? PdfFile } 
      count.should be 1 
    end

    it "describes the pdf file correctly" do 
      @deriv.description.should == "PDF generated off of Word document at #{@master.pid}"
    end

    it "assigns some content" do 
      @deriv.content.content.should_not be nil 
    end

    it "assigns the title correctly" do 
      @deriv.title.should == "#{@master.title} pdf" 
    end

    it "attaches the pdf to core" do 
      @deriv.core_record.should == @master.core_record 
    end

     it "clones permissions of the original object." do 
      @deriv.permissions.should == @master.permissions 
    end

    it "assigns keywords" do 
      @deriv.keywords.should =~ @master.keywords 
    end

    it "labels the content datastream correctly" do 
      @deriv.content.label.should == "test_docx.pdf" 
    end
  end

  describe "of word documents to thumbnails" do
    before(:all) { transform_context(:docx_file, :word_to_thumbnail) } 
    after(:all)  { @core.destroy }
    
    it_should_behave_like "a thumbnail generating transformation"

    # Pdf generation smoke test

    it "generates an intermediate PDF document" do 
      count = @core.content_objects.count { |c| c.instance_of? PdfFile } 
      count.should be 1 
    end
  end
end