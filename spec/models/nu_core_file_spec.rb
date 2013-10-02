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
      a = NuCoreFile.new(depositor: "bill@example.com")
      a.rightsMetadata.permissions({person: 'bill@example.com'}, 'edit')
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
    before :all do 
      @core_file = NuCoreFile.create(depositor: "dummy@example.com") 
      @img = ImageMasterFile.create(title: "Img", core_record: @core_file) 
      @pdf = PdfFile.create(title: "Pdf", core_record: @core_file) 
      @word = MswordFile.create(title: "MsWord", core_record: @core_file)
      @word_unassociated = MswordFile.create(title: "MsWordTwo")  
    end

    after(:all) { ActiveFedora::Base.destroy_all } 


    it "can be found using the .content_objects method" do 
      result = @core_file.content_objects

      result.length.should == 3
      result.should include @img 
      result.should include @pdf 
      result.should include @word
      result.should_not include @word_unassociated
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


