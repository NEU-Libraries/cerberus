require 'spec_helper'
include MimeHelper
include ChecksumHelper
include ActionDispatch::TestProcess
include Cerberus::TempFileStorage

describe ContentAttachmentJob do
  before(:each) do
    @user = FactoryGirl.create(:admin)
    @core_file = FactoryGirl.create(:complete_file, depositor:"000000000")
    @core_file.canonical_class = "VideoFile"
    @core_file.save!
    @content_object = VideoMasterFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
    file = fixture_file_upload("/files/video.mp4")
    new_path = move_file_to_tmp(file)
    @content_object.tmp_path = new_path
    @content_object.original_filename = file.original_filename
    @content_object.save!
    @permissions = {"identity"=>["northeastern:drs:repository:staff", "northeastern:drs:repository:loaders:emsa_emc"], "permission_type"=>["edit", "read"]}
    @mass_permissions = "public"
    @job = ContentAttachmentJob.new(@core_file.pid, @content_object.tmp_path, @content_object.pid, @content_object.original_filename, @permissions, @mass_permissions)
    @job.run
    @core_file.reload
    @content_object.reload
  end

  after(:each) do
    ActiveFedora::Base.destroy_all
    User.destroy_all
  end

  it "gets core_file" do
    @job.core_file_pid.should == @core_file.pid
    @job.core_record.should == @core_file
  end

  it "gets content_object" do
    @job.content_object_pid.should == @content_object.pid
    @job.content_object.should == @content_object
  end

  it "adds the file to the content_object" do
    @content_object.content.should be_kind_of(FileContentDatastream)
  end

  it "sets the core_record for the content_object" do
    @core_file.content_objects.should include(@content_object)
  end

  it "sets the title to the filename" do
    @content_object.title.should == @content_object.original_filename
  end

  it "sets the identifier to the pid" do
    @content_object.identifier.should == @content_object.pid
  end

  it "sets permissions" do
    @content_object.permissions.should == [{:type=>"group", :access=>"read", :name=>"northeastern:drs:repository:loaders:emsa_emc"}, {:type=>"group", :access=>"read", :name=>"public"}, {:type=>"group", :access=>"edit", :name=>"northeastern:drs:repository:staff"}]
  end

  it "sets mass permissions" do
    @content_object.mass_permissions.should == "public"
  end

  it "sets original_filename" do
    @content_object.original_filename.should == @content_object.original_filename
  end

  it "sets md5" do
    file = fixture_file_upload("/files/video.mp4")
    new_path = copy_file_to_tmp(file)
    @content_object.properties.md5_checksum.should == [new_checksum(new_path)]
  end

  it "sets mime_type" do
    file = fixture_file_upload("/files/video.mp4")
    new_path = copy_file_to_tmp(file)
    @content_object.properties.mime_type.should == [extract_mime_type(new_path)]
  end

  it "deletes tmp file" do
    # TODO
  end
end
