require 'spec_helper'

describe NuCoreFile do

  describe "In progress state" do
    let(:bill) { FactoryGirl.create(:bill) }
    let(:bo) { FactoryGirl.create(:bo) }
    let(:gf) { NuCoreFile.new }

    it "is false if the current user is not the depositor" do
      gf.depositor = bill.nuid
      gf.tag_as_in_progress

      gf.in_progress_for_user?(bo).should be false
    end

    it "is false if the current user is the depositor but the file isn't tagged as in progress" do
      gf.depositor = bill.nuid

      gf.in_progress_for_user?(bill).should be false
    end

    it "is true if the current user is the depositor and the file is in progress" do
      gf.depositor = bill.nuid
      gf.tag_as_in_progress

      gf.in_progress_for_user?(bill).should be true
    end
  end

  describe "Setting parent" do
    let(:bill) { FactoryGirl.create(:bill) }
    let(:bo) { FactoryGirl.create(:bo) }
    let(:bills_collection) { FactoryGirl.create(:valid_owned_by_bill) }
    let(:bills_collection_two) { FactoryGirl.create(:valid_owned_by_bill) }
    let(:core) do
      a = NuCoreFile.new(depositor: "000000001")
      a.rightsMetadata.permissions({person: '000000001'}, 'edit')
      return a
    end

    it "succeeds when the user has edit permissions on the targetted collection" do
      core.set_parent(bills_collection, bill).should be true
      core.parent.should == bills_collection
      core.save!

      bills_collection.child_file_ids.include?(core.pid).should be true
    end

    it "fails when the user does not have edit permissions on the targetted collection" do
      expect{ set_parent(bills_collection, bo) }.to raise_error
    end

    it "only allows a single entry" do
      core.set_parent(bills_collection, bill).should be true
      core.set_parent(bills_collection_two, bill).should be true

      core.parent.should == bills_collection_two
      core.relationships(:is_member_of).length.should == 1

      core.save!

      bills_collection.child_file_ids.include?(core.pid).should be false
      bills_collection_two.child_file_ids.include?(core.pid).should be true
    end
  end

  describe "Content files" do
    before :each do
      @core_file = NuCoreFile.create(depositor: "dummy@example.com")
      @img = ImageMasterFile.create(title: "Img", core_record: @core_file)
      @pdf = PdfFile.create(title: "Pdf", core_record: @core_file)
      @word = MswordFile.create(title: "MsWord", core_record: @core_file)
      @word_unassociated = MswordFile.create(title: "MsWordTwo")
    end

    after(:all) { ActiveFedora::Base.destroy_all }


    it "are destroyed when the core record is destroyed" do
      @core_file.destroy
      ImageMasterFile.exists?(@img.pid).should be false
      PdfFile.exists?(@pdf.pid).should be false
      MswordFile.exists?(@word.pid).should be false
      MswordFile.exists?(@word_unassociated.pid).should be true
    end

    it "can be found using the .content_objects method" do
      result = @core_file.content_objects

      result.length.should == 3
      result.should include @img
      result.should include @pdf
      result.should include @word
      result.should_not include @word_unassociated
    end

    it "update their metadata when told to" do
      @core_file.mass_permissions.should == "private"
      @img.mass_permissions.should  == "private"
      @pdf.mass_permissions.should  == "private"
      @word.mass_permissions.should == "private"

      @core_file.mass_permissions = "public"
      @core_file.save! ; @core_file.propagate_metadata_changes!

      @img.reload ; @pdf.reload ; @word.reload

      @img.mass_permissions.should  == "public"
      @pdf.mass_permissions.should  == "public"
      @word.mass_permissions.should == "public"
    end
  end

  describe "Canonical object lookup" do
    let(:core) { NuCoreFile.create(depositor: "dummy@example.com") }
    after(:all) { ActiveFedora::Base.destroy_all }

    it "returns false for objects with no canonical object" do
      core.canonical_object.should be false
    end

    it "returns the object for core objects with a canonical object" do
      @img = ImageMasterFile.new(title: "Img", core_record: core)
      @img.canonize && @img.save!
      core.reload

      core.canonical_object.should == @img
    end
  end

  describe "Thumbnail lookup" do
    let(:core) { NuCoreFile.create(depositor: "dummy@example.com") }
    after(:all)  { ActiveFedora::Base.destroy_all }

    it "returns false for objects with no thumbnail" do
      core.thumbnail.should be false
    end

    it "returns the object for core objects with a thumbnail" do
      @thumb = ImageThumbnailFile.create(title: "thumb", core_record: core)
      core.thumbnail.should == @thumb
    end
  end
end


