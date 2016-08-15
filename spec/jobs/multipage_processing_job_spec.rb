require 'spec_helper'

describe MultipageProcessingJob do
  before :each do
    `mysql -u "#{ENV["HANDLE_TEST_USERNAME"]}" < "#{Rails.root}"/spec/fixtures/files/handlesTEST.sql`
    @client = Mysql2::Client.new(:host => "#{ENV["HANDLE_TEST_HOST"]}", :username => "#{ENV["HANDLE_TEST_USERNAME"]}", :password => "#{ENV["HANDLE_TEST_PASSWORD"]}", :database => "#{ENV["HANDLE_TEST_DATABASE"]}")
    @collection = FactoryGirl.create(:root_collection)
    @parent = @collection.pid
    @copyright = "Test Copyright Statement"
    @user = FactoryGirl.create(:admin)
    @loader_name = "Multipage"
    @report_id = Loaders::LoadReport.create_from_strings(@user, 0, @loader_name, @parent)
    @load_report = Loaders::LoadReport.find(@report_id)
    @core_file = CoreFile.create(title:"Title", parent:@collection, mass_permissions: "public", depositor:@user.nuid)
    uniq_hsh = Digest::MD5.hexdigest("#{Rails.root}/spec/fixtures/files/multipage.zip")[0,2]
    file_name = "#{Time.now.to_f.to_s.gsub!('.','-')}-#{uniq_hsh}"
    new_path = Rails.application.config.tmp_path (file_name).to_s
    new_file = "#{new_path}.zip"
    zip_path = new_file.to_s
    @dir_path = File.join(File.dirname(zip_path), File.basename(zip_path, ".*"))
  end

  after :each do
    @client.query("DROP DATABASE #{ENV["HANDLE_TEST_DATABASE"]};")
    @user.destroy if @user
    Loaders::ItemReport.destroy_all
    Loaders::LoadReport.destroy_all
    ActiveFedora::Base.destroy_all
  end

  describe "failure if the image doesn't exist" do
    it "fails if the image file doesn't exist" do
      row_results = {"file_name"=>"not_a_real_file.tif", "title"=>"Title"}
      zip_files = []
      MultipageProcessingJob.new(@dir_path, row_results, @core_file.pid, @load_report.id, zip_files, @client).run
      Loaders::ItemReport.all.count.should == 1
      images = Loaders::ItemReport.where(load_report_id:"#{@report_id}").find_all
      images.count.should == 1
      images.first.validity.should be false
      images.first.pid.should be nil
      expect { CoreFile.find("#{images.first.pid}").to raise_error ActiveFedora::ObjectNotFoundError }
    end
  end

  describe "not true multipage object" do
    it "makes single image master file if one image" do
      FileUtils.cp("#{Rails.root}/spec/fixtures/files/multipage/bdr_43889.tif", "#{@dir_path}/bdr_43889.tif")
      @core_file = CoreFile.find("#{@core_file.pid}")
      row_results = {"file_name"=>"bdr_43889.tif", "title"=>"Title", "parent_filename"=>"bdr.mods.xml", "sequence"=>1, "last_item"=>"TRUE"}
      zip_files = ["bdr_43889.tif"]
      MultipageProcessingJob.new(@dir_path, row_results, @core_file.pid, @load_report.id, zip_files, @client).run
      ImageMasterFile.count.should == 1
      image = ImageMasterFile.first
      image.core_record.should == @core_file
      @core_file.canonical_object.should == image
      @core_file.page_objects.length.should == 0
      @core_file.canonical_class.should == "ImageMasterFile"
      image.depositor.should == @core_file.depositor
      @core_file.thumbnail_list.length.should == 5
      @core_file.identifier.should_not == nil
      @core_file.mods.identifier.should_not == nil
      @core_file.mods.identifier.type.should == ["hdl"]
      @load_report.reload.item_reports.count.should == 1
      UploadAlert.where(:pid=>@core_file.pid).count.should == 1
      UploadAlert.where(:pid=>@core_file.pid).first.load_type.should == "multipage"
    end
  end

  describe "true multipage object, not the first or last image" do
    before :each do
      FileUtils.cp("#{Rails.root}/spec/fixtures/files/multipage/bdr_43889.tif", "#{@dir_path}/bdr_43889.tif")
      @core_file = CoreFile.find("#{@core_file.pid}")
      row_results = {"file_name"=>"bdr_43889.tif", "title"=>"Title", "parent_filename"=>"bdr.mods.xml", "sequence"=>"7", "last_item"=>""}
      zip_files = []
      MultipageProcessingJob.new(@dir_path, row_results, @core_file.pid, @load_report.id, nil, @client).run
    end

    it "creates the pagefile object" do
      PageFile.count.should == 1
      page = PageFile.first
      @core_file.page_objects.length.should == 1
    end

    it "sets title to core_file title" do
      page = PageFile.first
      page.title.should == @core_file.title
    end

    it "sets identifier to pid" do
      page = PageFile.first
      page.identifier.should == page.pid
    end

    it "sets keywords to core_file keywords" do
      page = PageFile.first
      page.keywords.should ==  @core_file.keywords.flatten
    end

    it "sets depositor to core_file depositor" do
      page = PageFile.first
      page.depositor.should == @core_file.depositor
    end

    it "sets core_record to core_file" do
      page = PageFile.first
      page.core_record.should == @core_file
    end

    it "sets ordinal values" do
      page = PageFile.first
      page.ordinal_value.should == 7
      page.ordinal_last.should == false
    end

    it "does not assign canonical" do
      @core_file.canonical_object.should == false #won't have canonical object until it is the last item
      @core_file.canonical_class.should == nil #won't have a canonical_class until it is the last item
    end

    it "does not create thumbnail_list" do
      @core_file.thumbnail_list.length.should == 0 #won't make a thumbnail list becuase it isn't the first one
    end

    it "does not generate item_reports" do
      @load_report.reload.item_reports.count.should == 0 #won't generate success image report until it is the last item
    end

    it "does not create upload alert" do
      UploadAlert.where(:pid=>@core_file.pid).count.should == 0
    end
  end

  describe "true multipage object, first image" do
    before :each do
      FileUtils.cp("#{Rails.root}/spec/fixtures/files/multipage/bdr_43889.tif", "#{@dir_path}/bdr_43889.tif")
      @core_file = CoreFile.find("#{@core_file.pid}")
      row_results = {"file_name"=>"bdr_43889.tif", "title"=>"Title", "parent_filename"=>"bdr.mods.xml", "sequence"=>"1", "last_item"=>""}
      zip_files = []
      MultipageProcessingJob.new(@dir_path, row_results, @core_file.pid, @load_report.id, nil, @client).run
    end

    it "creates the pagefile object" do
      PageFile.count.should == 1
      page = PageFile.first
      @core_file.page_objects.length.should == 1
    end

    it "sets title to core_file title" do
      page = PageFile.first
      page.title.should == @core_file.title
    end

    it "sets identifier to pid" do
      page = PageFile.first
      page.identifier.should == page.pid
    end

    it "sets keywords to core_file keywords" do
      page = PageFile.first
      page.keywords.should ==  @core_file.keywords.flatten
    end

    it "sets depositor to core_file depositor" do
      page = PageFile.first
      page.depositor.should == @core_file.depositor
    end

    it "sets core_record to core_file" do
      page = PageFile.first
      page.core_record.should == @core_file
    end

    it "sets ordinal values" do
      page = PageFile.first
      page.ordinal_value.should == 1
      page.ordinal_last.should == false
    end

    it "sets the thumbnail list" do
      @core_file.thumbnail_list.length.should == 5 #makes a thumbnail list becuase it is the first one
    end

    it "does not assign canonical" do
      @core_file.canonical_object.should == false #won't have canonical object until it is the last item
      @core_file.canonical_class.should == nil #won't have a canonical_class until it is the last item
    end

    it "does not generate item_reports" do
      @load_report.reload.item_reports.count.should == 0 #won't generate success image report until it is the last item
    end

    it "does not create upload alert" do
      UploadAlert.where(:pid=>@core_file.pid).count.should == 0
    end
  end

  describe "true multipage object, last image" do
    before :each do
      FileUtils.cp("#{Rails.root}/spec/fixtures/files/multipage/bdr_43890.tif", "#{@dir_path}/bdr_43890.tif")
      @core_file = CoreFile.find("#{@core_file.pid}")
      row_results = {"file_name"=>"bdr_43890.tif", "title"=>"Title", "parent_filename"=>"bdr.mods.xml", "sequence"=>"2", "last_item"=>"TRUE"}
      zip_files = ["bdr_43889.tif","bdr_43890.tif"]
      MultipageProcessingJob.new(@dir_path, row_results, @core_file.pid, @load_report.id, zip_files, @client).run
    end

    it "creates the pagefile object" do
      PageFile.count.should == 1
      page = PageFile.first
      @core_file.page_objects.length.should == 1
    end

    it "sets title to core_file title" do
      page = PageFile.first
      page.title.should == @core_file.title
    end

    it "sets identifier to pid" do
      page = PageFile.first
      page.identifier.should == page.pid
    end

    it "sets keywords to core_file keywords" do
      page = PageFile.first
      page.keywords.should ==  @core_file.keywords.flatten
    end

    it "sets depositor to core_file depositor" do
      page = PageFile.first
      page.depositor.should == @core_file.depositor
    end

    it "sets core_record to core_file" do
      page = PageFile.first
      page.core_record.should == @core_file
    end

    it "sets ordinal values" do
      page = PageFile.first
      page.ordinal_value.should == 2
      page.properties.ordinal_last.should == ["TRUE"]
    end

    it "does not set the thumbnail list" do
      @core_file.thumbnail_list.length.should == 0 #doesn't make a thumbnail list becuase it is not the first one
    end

    it "assigns canonical" do
      @core_file.canonical_class.should == "ZipFile"
    end

    it "generates item_reports" do
      @load_report.reload.item_reports.count.should == 1
      UploadAlert.where(:pid=>@core_file.pid).count.should == 1
      UploadAlert.where(:pid=>@core_file.pid).first.load_type.should == "multipage"
    end

    it "creates handle" do
      @core_file.reload
      @core_file.identifier.should_not == nil
      @core_file.mods.identifier.type.should == ["hdl"]
    end
  end

end
