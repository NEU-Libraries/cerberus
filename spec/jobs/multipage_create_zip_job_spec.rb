require 'spec_helper'
describe "MultipageCreateZipJob" do
  before :each do
    @collection = FactoryGirl.create(:root_collection)
    @user = FactoryGirl.create(:admin)
    @core_file = CoreFile.create(title:"Title", parent:@collection, mass_permissions: "public", depositor:@user.nuid)
    uniq_hsh = Digest::MD5.hexdigest("#{Rails.root}/spec/fixtures/files/multipage.zip")[0,2]
    file_name = "#{Time.now.to_f.to_s.gsub!('.','-')}-#{uniq_hsh}"
    new_path = Rails.application.config.tmp_path (file_name).to_s
    new_file = "#{new_path}.zip"
    zip_path = new_file.to_s
    @dir_path = File.join(File.dirname(zip_path), File.basename(zip_path, ".*"))
    @zip_files = ["bdr_43889.tif","bdr_43890.tif"]
  end

  after :each do
    ActiveFedora::Base.destroy_all
    @user.destroy
  end

  context "core_file does not exist" do
    it "does not create zipfile" do
      core_file_pid = @core_file.pid
      @core_file.destroy
      expect { MultipageCreateZipJob.new(@dir_path, core_file_pid, @zip_files).run.to raise_error ActiveFedora::ObjectNotFoundError }
      ZipFile.count.should == 0
    end
  end

  context "zip_files blank" do
    it "does not create zipfile" do
      @zip_files = []
      MultipageCreateZipJob.new(@dir_path, @core_file.pid, @zip_files).run
      ZipFile.count.should == 0
    end
  end

  context "success" do
    before :each do
      time = Time.now
      MultipageCreateZipJob.new(@dir_path, @core_file.pid, @zip_files).run
    end

    it "creates zipfile" do
      ZipFile.count.should == 1
    end

    it "sets depositor" do
      zip = ZipFile.first
      zip.depositor.should == @core_file.depositor
    end

    it "sets core_record" do
      zip = ZipFile.first
      zip.core_record.should == @core_file
    end

    it "sets permissions" do
      zip = ZipFile.first
      zip.permissions.should == @core_file.permissions
    end

    it "sets mimetype" do
      zip = ZipFile.first
      zip.properties.mime_type.should == ["application/zip"]
    end

    it "sets md5_checksum" do
      zip = ZipFile.first
      zip.properties.md5_checksum.should_not == nil
    end

    it "canonizes" do
      zip = ZipFile.first
      @core_file.canonical_object.should == zip
    end
  end


end
