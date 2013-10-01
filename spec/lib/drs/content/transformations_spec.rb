require 'spec_helper' 

describe Drs::Content::Transformations do 

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

  describe "of word documents to pdfs" do 
    before :all do 
      @master = FactoryGirl.create(:docx_file) 
      @core = @master.core_record 
      @pdf = Drs::Content::Transformations.word_to_pdf(@master) 
    end

    after(:all) { ActiveFedora::Base.destroy_all } 

    it "creates one and only one PdfFile" do 
      count = @core.content_objects.count { |c| c.instance_of? PdfFile } 
      count.should be 1 
    end

    it "describes the pdf file correctly" do 
      @pdf.description.should == "PDF generated off of Word document at #{@master.pid}"
    end

    it "assigns some content" do 
      @pdf.content.content.should_not be nil 
    end

    it "assigns the title correctly" do 
      @pdf.title.should == "#{@master.title} pdf" 
    end

    it "attaches the pdf to core" do 
      @pdf.core_record.should == @master.core_record 
    end

     it "clones permissions of the original object." do 
      @pdf.permissions.should == @master.permissions 
    end

    it "assigns keywords" do 
      @pdf.keywords.should =~ @master.keywords 
    end

    it "labels the content datastream correctly" do 
      @pdf.content.label.should == "test_docx.pdf" 
    end
  end
end