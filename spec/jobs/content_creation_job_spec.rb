require 'spec_helper'

describe ContentCreationJob, unless: $in_travis do

  # Image Formats
  let(:jpeg_path) { "#{Rails.root}/spec/fixtures/files/test_pic.jpeg" }
  let(:tif_path)  { "#{Rails.root}/spec/fixtures/files/image.tif" }
  let(:gif_path)  { "#{Rails.root}/spec/fixtures/files/image.gif" }
  let(:png_path)  { "#{Rails.root}/spec/fixtures/files/image.png" }

  # Pdf Formats
  let(:pdf_path)  { "#{Rails.root}/spec/fixtures/files/test.pdf" }

  # Word Formats
  let(:docx_path) { "#{Rails.root}/spec/fixtures/files/test_docx.docx" }
  let(:doc_path)  { "#{Rails.root}/spec/fixtures/files/word.doc" }

  # Excel Formats
  let(:xls_path)  { "#{Rails.root}/spec/fixtures/files/excel.xls" }
  let(:xlsx_path) { "#{Rails.root}/spec/fixtures/files/excel.xlsx" }

  # Note that we are testing a private method with :send here.
  # Given that correct type selection is the most complex part
  # of the process, this seemed reasonable.
  # describe "Object type selection" do
  #   def return_obj(path, name)
  #     a = ContentCreationJob.new(false, false, false, false)
  #     a.send(:instantiate_appropriate_content_object, path, name)
  #   end

  #   it "knows when to create an image" do
  #     return_obj(jpeg_path, "test_pic.jpeg").should be_an_instance_of ImageMasterFile
  #     return_obj(tif_path, "image.tif").should      be_an_instance_of ImageMasterFile
  #     return_obj(gif_path, "image.gif").should      be_an_instance_of ImageMasterFile
  #     return_obj(png_path, "image.png").should      be_an_instance_of ImageMasterFile
  #   end

  #   it "knows when to create a pdf" do
  #     return_obj(pdf_path, "test.pdf").should be_an_instance_of PdfFile
  #   end

  #   it "knows when to create a word file" do
  #     return_obj(docx_path, "test_docx.docx").should be_an_instance_of MswordFile
  #     return_obj(doc_path, "word.doc").should be_an_instance_of MswordFile
  #   end

  #   it "knows when to create an excel file" do
  #     return_obj(xls_path, 'excel.xls').should be_an_instance_of MsexcelFile
  #     return_obj(xlsx_path, 'excel.xlsx').should be_an_instance_of MsexcelFile
  #   end
  # end

  def context(o_path)
    @user = FactoryGirl.create(:user)
    root =  FactoryGirl.create(:root_collection)
    @core = FactoryGirl.create(:complete_file, depositor: @user.nuid, parent: root)
    @fn = File.basename(o_path)
    FileUtils.cp(o_path, "#{Rails.application.config.tmp_path}/#{@fn}")
    @path = "#{Rails.application.config.tmp_path}/#{@fn}"
    @core.instantiate_appropriate_content_object(@path)
    @master = ContentCreationJob.new(@core.pid, @path, @fn).run
  end

  def clear_context
    @user.destroy if @user
    @core.destroy if @core
  end

  shared_examples_for "master creation process" do
    it "attaches the master to the core record" do
      @master.core_record.should == @core
    end

    it "labels the file with original filename" do
      @master.title.should == @fn
    end

    it "makes the given user the depositor" do
      @master.depositor.should == @user.nuid
    end

    it "assigns the permissions of the core record" do
      @master.permissions.should == @core.permissions
    end

    it "assigns some content" do
      @master.content.content.should_not be nil
    end
  end

  describe "Image creation" do
    before(:all) { context("#{Rails.root}/spec/fixtures/files/test_pic.jpeg") }
    after(:all)  { clear_context }

    it "labels the content stream correctly" do
      @master.content.label.should == "test_pic.jpeg"
    end

    it "updates the core record appropriately" do
      @core.reload
      @core.obj_type.should == "still image"
    end

    it_should_behave_like "master creation process"
  end

  # describe "Zip creation" do
  #   before(:all) { context("#{Rails.root}/spec/fixtures/files/zip.ott") }
  #   after(:all)  { clear_context }

  #   it "labels the content stream correctly" do
  #     @master.content.label.should == "zip.zip"
  #   end

  #   it "assigns appropriate type to the core record" do
  #     @core.reload
  #     @core.dcmi_type.should == "unknown"
  #   end

  #   it_should_behave_like "master creation process"
  # end

  # TODO: redo this test with sentinels
  # describe "Master creation with irregular permissions" do
  #   before(:all) do
  #     @user = FactoryGirl.create(:user)
  #     root =  FactoryGirl.create(:root_collection)
  #     @core = FactoryGirl.create(:complete_file, depositor: @user.nuid, parent: root)
  #     @fn = File.basename("#{Rails.root}/spec/fixtures/files/test_pic.jpeg")
  #     FileUtils.cp("#{Rails.root}/spec/fixtures/files/test_pic.jpeg", "#{Rails.application.config.tmp_path}/#{@fn}")
  #     @path = "#{Rails.application.config.tmp_path}/#{@fn}"
  #     @core.instantiate_appropriate_content_object(@path)
  #     # @permissions = {"ImageMasterFile" => {"read"  => ["northeastern:drs:repository:test"], "edit" => ["northeastern:drs:repository:master"]}}
  #     @master = ContentCreationJob.new(@core.pid, @path, @fn, nil, 0, 0, 0, true).run
  #   end
  #
  #   it "should set correct permissions for master file" do
  #     @master.permissions.should == [{:type=>"group", :access=>"read", :name=>"northeastern:drs:repository:test"}, {:type=>"group", :access=>"edit", :name=>"northeastern:drs:repository:master"}, {:type=>"user", :access=>"edit", :name=>"#{@user.nuid}"}]
  #   end
  #
  #   after(:all)  { clear_context }
  # end
end
