require 'spec_helper'
include ChecksumHelper

describe IiifImageCreateJob do
  before(:all) do
    @user        = FactoryGirl.create(:bill)
    @tif         = FactoryGirl.create(:tif_master_file)
    @tif_16      = FactoryGirl.create(:tif_16bit_master_file)
    @jpg         = FactoryGirl.create(:image_master_file)
  end

  it "should raise error if collection not found" do
    job = IiifImageCreateJob.new("neu:123")
    expect {job.run}.to raise_error ActiveFedora::ObjectNotFoundError
  end

  describe "image creation" do
    before(:all) do
      @job = IiifImageCreateJob.new(@tif.core_record.parent.pid)
      @job.run
    end

    it "should not do anything with non-tifs" do
      @jpg.core_record.content_objects.length.should == 1
    end

    it "should not do anything with 8bit tifs" do
      @tif.core_record.content_objects.length.should == 1
    end

    it "should create create new ImageMasterFile for >8bit tifs" do
      @tif_16.core_record.content_objects.length.should == 2
    end

    it "should inherit depositor" do
      @tif_16.core_record.iiif_object.depositor.should == @tif_16.core_record.depositor
    end

    it "should set the iiif properties value and be solrized" do
      @tif_16.core_record.iiif_object.properties.iiif.should == ["true"]
      doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{@tif_16.core_record.iiif_object.pid}\"").first)
      doc['iiif_tesim'].should == ["true"]
    end

    it "should clean up tmp directory" do
      File.exists?(@tif_16.core_record.iiif_object.tmp_path).should be_false
    end

    it "should generate checksum" do
      checksum = new_checksum(@tif_16.core_record.iiif_object.fedora_file_path)
      @tif_16.core_record.iiif_object.properties.md5_checksum.should == [checksum]
    end

    it "should not create a new iiif object if there already is one" do
      @job.run
      @tif_16.core_record.content_objects.length.should == 2
    end

    it "should get permissions from canonical object if no sentinel" do
      @tif_16.core_record.iiif_object.mass_permissions.should == @tif_16.core_record.canonical_object.mass_permissions
      @tif_16.core_record.iiif_object.permissions.should =~ @tif_16.core_record.canonical_object.permissions << {:type=>"group", :access=>"edit", :name=>"northeastern:drs:repository:staff"}
    end

    after(:all) do
      ImageLargeFile.destroy_all
    end
  end

  it "should get permissions from sentinel if present" do
    col = @tif_16.core_record.parent
    sentinel = Sentinel.new({"set_pid"=>col.pid, "image_large"=>{"mass_permissions"=>"private", "permissions"=>{"permission_type"=>["read"], "identity"=>["northeastern:drs:repository:loaders:aai_archives"]}}})
    sentinel.save!
    @job = IiifImageCreateJob.new(@tif.core_record.parent.pid)
    @job.run
    @tif_16.core_record.iiif_object.mass_permissions.should == "private"
    @tif_16.core_record.iiif_object.permissions.should == [{:type=>"group", :access=>"read", :name=>"northeastern:drs:repository:loaders:aai_archives"}, {:type=>"group", :access=>"edit", :name=>"northeastern:drs:repository:staff"}, {:type=>"user", :access=>"edit", :name=>"nosuch@example.com"}]
    ImageLargeFile.destroy_all
    Sentinel.destroy_all
  end

  after(:all) do
    ActiveFedora::Base.destroy_all
    User.destroy_all
    Sentinel.destroy_all
  end
end
