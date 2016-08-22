require 'spec_helper'
include SpreadsheetHelper

describe ProcessXmlZipJob do
  before(:all) do
    `mysql -u "#{ENV["HANDLE_USERNAME"]}" < "#{Rails.root}"/spec/fixtures/files/handlesTEST.sql`
    @client = Mysql2::Client.new(:host => "#{ENV["HANDLE_TEST_HOST"]}", :username => "#{ENV["HANDLE_TEST_USERNAME"]}", :password => "#{ENV["HANDLE_TEST_PASSWORD"]}", :database => "#{ENV["HANDLE_TEST_DATABASE"]}")
    @loader_name = "XML"
    @user = FactoryGirl.create(:admin)
  end

  after(:all) do
    @client.query("DROP DATABASE #{ENV["HANDLE_TEST_DATABASE"]};")
    @user.destroy if @user
    Loaders::LoadReport.destroy_all
    Loaders::ItemReport.destroy_all
    ActiveFedora::Base.destroy_all
  end

  context "preview file" do
    before :all do
      spreadsheet_file_path = "#{Rails.root}/spec/fixtures/files/xml_loader_preview/manifest-preview.xlsx"
      copyright = ""
      @parent = FactoryGirl.create(:root_collection)
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      file_name = File.basename(spreadsheet_file_path)
      new_path = tempdir.join(file_name).to_s
      FileUtils.cp(spreadsheet_file_path, new_path)
      permissions = @parent.permissions
      @report_id = Loaders::LoadReport.create_from_strings(@user, 0, @loader_name, @parent.pid)
      @lr = Loaders::LoadReport.find("#{@report_id}")
      ProcessXmlZipJob.new(@loader_name, spreadsheet_file_path, @parent, copyright, @user, permissions, @report_id, false, nil, true, @client).run
    end

    it "should create preview if passed preview flag" do
      @lr.reload
      CoreFile.exists?(@lr.preview_file_pid).should be true
    end

    it "should create preview if passed preview flag" do
      @lr.reload
      cf = CoreFile.find(@lr.preview_file_pid)
      cf.mods.content.should == xml_decode(File.open("#{Rails.root}/spec/fixtures/files/xml_loader_preview/sample_mods.xml", "r").read) + "\n"
    end


    after :all do
      Loaders::LoadReport.destroy_all
      Loaders::ItemReport.destroy_all
      ActiveFedora::Base.destroy_all
      FileUtils.rm_rf(Pathname.new("#{Rails.application.config.tmp_path}/")+"xml_loader_preview")
    end
  end

  shared_examples_for "successful uploads" do
    it "should update load report" do
      @lr.reload
      @lr.success_count.should == 1
    end

    it "should create item report" do
      @lr.reload
      @lr.item_reports.length.should == 1
    end

    it "should create upload alert" do
      UploadAlert.where(:pid=>@lr.item_reports.first.pid).count.should == 1
      UploadAlert.where(:pid=>@lr.item_reports.first.pid).first.load_type.should == "xml"
    end
  end

  context "existing files" do
    before :all do
      spreadsheet_file_path = "#{Rails.root}/spec/fixtures/files/xml_loader_existing/manifest-existing.xlsx"
      copyright = ""
      @parent = FactoryGirl.create(:root_collection)
      @corefile = CoreFile.create(pid: "neu:test123", title: "Core File Test", parent: @parent, depositor: @user.nuid, mass_permissions: "public")
      @corefile.keywords = ["test"]
      @corefile.identifier = "http://testhandle"
      @corefile.save!
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      dir_name = File.dirname(spreadsheet_file_path)
      new_path = tempdir.join("xml_loader_existing").to_s
      FileUtils.cp_r(dir_name, new_path)
      new_file = new_path +"/manifest-existing.xlsx"
      permissions = @parent.permissions
      @report_id = Loaders::LoadReport.create_from_strings(@user, 0, @loader_name, @parent.pid)
      @lr = Loaders::LoadReport.find("#{@report_id}")
      depositor = @user.nuid
      ProcessXmlZipJob.new(@loader_name, new_file, @parent, copyright, @user, permissions, @report_id, true, depositor, nil, @client).run
    end

    it "should update existing file if existing file spreadsheet" do
      CoreFile.exists?(@corefile.pid).should be true
      @lr.reload.item_reports.first.pid.should == @corefile.pid
    end

    it "should carry over handle" do
      @corefile.reload.identifier.should == "http://testhandle"
    end

    it "should set mods content to content of file" do
      @corefile.mods.content.should == xml_decode(File.open("#{Rails.root}/spec/fixtures/files/xml_loader_existing/sample_mods_with_handle.xml", "r").read) + "\n"
    end

    it_should_behave_like "successful uploads"

    after :all do
      Loaders::LoadReport.destroy_all
      Loaders::ItemReport.destroy_all
      ActiveFedora::Base.destroy_all
      FileUtils.rm_rf(Pathname.new("#{Rails.application.config.tmp_path}/")+"xml_loader_existing")
    end
  end

  context "new files" do
    before :all do
      spreadsheet_file_path = "#{Rails.root}/spec/fixtures/files/xml_loader_new/manifest-new.xlsx"
      copyright = ""
      @parent = FactoryGirl.create(:root_collection)
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      dir_name = File.dirname(spreadsheet_file_path)
      new_path = tempdir.join("xml_loader_new").to_s
      FileUtils.cp_r(dir_name, new_path)
      new_file = new_path +"/manifest-new.xlsx"
      permissions = @parent.permissions
      @report_id = Loaders::LoadReport.create_from_strings(@user, 0, @loader_name, @parent.pid)
      @lr = Loaders::LoadReport.find("#{@report_id}")
      depositor = @user.nuid
      ProcessXmlZipJob.new(@loader_name, new_file, @parent, copyright, @user, permissions, @report_id, false, depositor, nil, @client).run
    end

    it "should create new file if new file spreadsheet" do
      @lr.reload
      CoreFile.exists?(@lr.item_reports.first.pid).should be true
    end

    it "should set embargo date if embargo true and embargo date in correct format" do
      cf = CoreFile.find(@lr.reload.item_reports.first.pid)
      cf.embargo_release_date.should == "2099-10-01"
    end

    it "should give depositor edit access" do
      cf = CoreFile.find(@lr.reload.item_reports.first.pid)
      @user.can?(:edit, cf).should be true
    end

    it "should set depositor from value passed in" do
      cf = CoreFile.find(@lr.reload.item_reports.first.pid)
      cf.depositor.should == @user.nuid
    end

    it "should set rights metadata permissions from collection parent" do
      cf = CoreFile.find(@lr.reload.item_reports.first.pid)
      cf.permissions.should == @parent.permissions << {:type=>"user",:access=>"edit",:name=>@user.nuid}
    end

    it "should set original file_name" do
      cf = CoreFile.find(@lr.reload.item_reports.first.pid)
      cf.original_filename.should == "image.png"
    end

    it "should set label to file name" do
      cf = CoreFile.find(@lr.reload.item_reports.first.pid)
      cf.label.should == "image.png"
    end

    it "should instantiate_appropriate_content_object" do
      cf = CoreFile.find(@lr.reload.item_reports.first.pid)
      cf.canonical_class.should == "ImageMasterFile"
    end

    it "should make handle" do
      cf = CoreFile.find(@lr.reload.item_reports.first.pid)
      cf.identifier.should_not == ""
    end

    it "should set mods content to content of file" do
      cf = CoreFile.find(@lr.reload.item_reports.first.pid)
      mods = ModsDatastream.new
      mods.content = xml_decode(File.open("#{Rails.root}/spec/fixtures/files/xml_loader_new/sample_mods.xml", "r").read) + "\n"
      mods.identifier = cf.identifier
      cf.mods.content.should == mods.content
    end

    it_should_behave_like "successful uploads"

    after :all do
      Loaders::LoadReport.destroy_all
      Loaders::ItemReport.destroy_all
      ActiveFedora::Base.destroy_all
      FileUtils.rm_rf(Pathname.new("#{Rails.application.config.tmp_path}/")+"xml_loader_new")
    end
  end

  context "unsuccessful files" do
    before :each do
      @copyright = ""
      @parent = FactoryGirl.create(:root_collection)
      @corefile = CoreFile.create(pid: "neu:test123", title: "Core File Test", parent: @parent, depositor: @user.nuid, mass_permissions: "public")
      @corefile.keywords = ["test"]
      @corefile.identifier = "http://testhandle"
      @corefile.save!
      @permissions = @parent.permissions
      @report_id = Loaders::LoadReport.create_from_strings(@user, 0, @loader_name, @parent.pid)
      @lr = Loaders::LoadReport.find("#{@report_id}")
      @depositor = @user.nuid
      temp_dir = Pathname.new("#{Rails.application.config.tmp_path}/")
      @new_path = temp_dir.join("failing_xml_loads").to_s
      FileUtils.cp_r("#{Rails.root}/spec/fixtures/files/failing_xml_loads/", @new_path)
      UploadAlert.destroy_all
    end

    it "should fail if xml file does not exist" do
      new_file = @new_path + "/manifest-xmlDNE.xlsx"
      ProcessXmlZipJob.new(@loader_name, new_file, @parent, @copyright, @user, @permissions, @report_id, true, @depositor, nil, @client).run
      @lr.reload
      @lr.number_of_files.should == 1
      @lr.fail_count.should == 1
      @lr.item_reports.first.validity.should == false
      @lr.item_reports.first.exception.should == "Your upload could not be processed becuase the XML files could not be found."
      UploadAlert.where(:pid=>@lr.item_reports.first.pid).count.should == 0
    end

    it "should fail if pid does not exist" do
      new_file = @new_path + "/manifest-pidDNE.xlsx"
      ProcessXmlZipJob.new(@loader_name, new_file, @parent, @copyright, @user, @permissions, @report_id, true, @depositor, nil, @client).run
      @lr.reload
      @lr.number_of_files.should == 1
      @lr.fail_count.should == 1
      @lr.item_reports.first.validity.should == false
      @lr.item_reports.first.exception.should == "Core file neu:123 does not exist"
      UploadAlert.where(:pid=>@lr.item_reports.first.pid).count.should == 0
    end

    it "should fail if invalid mods" do
      new_file = @new_path + "/manifest-invldMODS.xlsx"
      ProcessXmlZipJob.new(@loader_name, new_file, @parent, @copyright, @user, @permissions, @report_id, true, @depositor, nil, @client).run
      @lr.reload
      @lr.number_of_files.should == 1
      @lr.fail_count.should == 1
      @lr.item_reports.first.validity.should == false
      @lr.item_reports.first.exception.should == "Nokogiri::XML::SyntaxError: Element '{http://www.loc.gov/mods/v3}languageTerm': This element is not expected.;"
      UploadAlert.where(:pid=>@lr.item_reports.first.pid).count.should == 0
    end

    it "should fail if empty spreadsheet" do
      new_file = @new_path + "/manifest-emptysheet.xlsx"
      expect {ProcessXmlZipJob.new(@loader_name, new_file, @parent, @copyright, @user, @permissions, @report_id, true, @depositor, nil, @client).run}.to raise_error
    end

    it "should fail if no header row" do
      new_file = @new_path + "/manifest-noheader.xlsx"
      ProcessXmlZipJob.new(@loader_name, new_file, @parent, @copyright, @user, @permissions, @report_id, true, @depositor, nil, @client).run
      @lr.reload
      @lr.number_of_files.should == 0
      @lr.fail_count.should == 0
    end

    it "should fail record if no title" do
      new_file = @new_path + "/manifest-no-title.xlsx"
      ProcessXmlZipJob.new(@loader_name, new_file, @parent, @copyright, @user, @permissions, @report_id, true, @depositor, nil, @client).run
      @lr.reload
      @lr.number_of_files.should == 1
      @lr.fail_count.should == 1
      @lr.item_reports.first.validity.should == false
      @lr.item_reports.first.exception.should == "Exceptions::MissingMetadata: No valid title in xml;"
      UploadAlert.where(:pid=>@lr.item_reports.first.pid).count.should == 0
    end

    it "should fail record if no keywords" do
      new_file = @new_path + "/manifest-no-keyword.xlsx"
      ProcessXmlZipJob.new(@loader_name, new_file, @parent, @copyright, @user, @permissions, @report_id, true, @depositor, nil, @client).run
      @lr.reload
      @lr.number_of_files.should == 1
      @lr.fail_count.should == 1
      @lr.item_reports.first.validity.should == false
      @lr.item_reports.first.exception.should == "Exceptions::MissingMetadata: No valid keywords in xml;"
      UploadAlert.where(:pid=>@lr.item_reports.first.pid).count.should == 0
    end

    it "should fail record if no handle" do
      new_file = @new_path + "/manifest-no-handle.xlsx"
      ProcessXmlZipJob.new(@loader_name, new_file, @parent, @copyright, @user, @permissions, @report_id, true, @depositor, nil, @client).run
      @lr.reload
      @lr.number_of_files.should == 1
      @lr.fail_count.should == 1
      @lr.item_reports.first.validity.should == false
      @lr.item_reports.first.exception.should == "Must have a handle"
      UploadAlert.where(:pid=>@lr.item_reports.first.pid).count.should == 0
    end

    it "should fail record if embargo date not correct format" do
      new_file = @new_path + "/manifest-invalid-embargo-date.xlsx"
      ProcessXmlZipJob.new(@loader_name, new_file, @parent, @copyright, @user, @permissions, @report_id, true, @depositor, nil, @client).run
      @lr.reload
      @lr.number_of_files.should == 1
      @lr.fail_count.should == 1
      @lr.item_reports.first.validity.should == false
      @lr.item_reports.first.exception.should == "Embargo date must follow format YYYY-MM-DD"
      UploadAlert.where(:pid=>@lr.item_reports.first.pid).count.should == 0
    end

    it "should fail record if no poster provided for video/audio" do
      new_file = @new_path + "/manifest-no-poster-for-av.xlsx"
      ProcessXmlZipJob.new(@loader_name, new_file, @parent, @copyright, @user, @permissions, @report_id, true, @depositor, nil, @client).run
      @lr.reload
      @lr.number_of_files.should == 1
      @lr.fail_count.should == 1
      @lr.item_reports.first.validity.should == false
      @lr.item_reports.first.exception.should == "Audio or Video File must have poster file"
      UploadAlert.where(:pid=>@lr.item_reports.first.pid).count.should == 0
    end

    after :each do
      Loaders::LoadReport.destroy_all
      Loaders::ItemReport.destroy_all
      ActiveFedora::Base.destroy_all
      FileUtils.rm_rf(Pathname.new("#{Rails.application.config.tmp_path}/")+"failing_xml_loads")
      UploadAlert.destroy_all
    end
  end
end
