require 'spec_helper'

describe CoreFile do

  describe "In progress state" do
    let(:bill) { FactoryGirl.create(:bill) }
    let(:bo) { FactoryGirl.create(:bo) }
    let(:gf) { CoreFile.new }

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

  describe "stream only state" do
    let(:bill) { FactoryGirl.create(:bill) }
    let(:bo) { FactoryGirl.create(:bo) }
    let(:gf) { CoreFile.new }

    it "is true if the file is tagged as in progress" do
      gf.tag_as_stream_only

      gf.stream_only?.should be true
    end
  end

  describe "Abandoned file lookup" do
    let(:bill) { FactoryGirl.create(:bill) }
    let(:nuid) { bill.nuid }
    let(:gf)   { CoreFile.new }

    it "returns the empty array if no abandoned files exist" do
      gf.depositor = nuid
      gf.save!
      expect(CoreFile.abandoned_for_nuid(nuid)).to eq []
    end

    it "returns an array of SolrDocuments" do
      begin
        @abandoned           = CoreFile.new
        @abandoned.depositor = nuid
        @abandoned.tag_as_incomplete
        @abandoned.save!

        # Note that this doesn't work very well, and that
        # the requirement of a one day jump is being imposed by
        # an inability to escape Timezone hell.  Can't seem to get
        # offsets to be interpretted correctly by Timecop.  Also
        # other things aren't working.
        Timecop.freeze(DateTime.now + 1) do
          expected = [SolrDocument.new(@abandoned.to_solr).pid]
          result   = CoreFile.abandoned_for_nuid(nuid).map { |x| x.pid }
          expect(result).to match_array expected
        end
      ensure
        @abandoned.destroy
      end
    end
  end

  describe "Setting parent" do
    let(:bill) { FactoryGirl.create(:bill) }
    let(:bo) { FactoryGirl.create(:bo) }
    let(:bills_collection) { FactoryGirl.create(:valid_owned_by_bill) }
    let(:bills_collection_two) { FactoryGirl.create(:valid_owned_by_bill) }
    let(:core) do
      a = CoreFile.new(depositor: "000000001")
      a.rightsMetadata.permissions({person: '000000001'}, 'edit')
      return a
    end

    it "succeeds when the user has edit permissions on the targetted collection" do
      core.set_parent(bills_collection, bill).should be true
      core.parent.should == bills_collection
      core.save!

      bills_collection.child_object_ids.include?(core.pid).should be true
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

      bills_collection.child_object_ids.include?(core.pid).should be false
      bills_collection_two.child_object_ids.include?(core.pid).should be true
    end
  end

  describe "Content files" do
    before :each do
      @core_file = CoreFile.create(depositor: "dummy@example.com")
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
    let(:core) { CoreFile.create(depositor: "dummy@example.com") }
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
    let(:core) { CoreFile.create(depositor: "dummy@example.com") }
    after(:all)  { ActiveFedora::Base.destroy_all }

    it "returns false for objects with no thumbnail" do
      core.thumbnail.should be false
    end

    it "returns the object for core objects with a thumbnail" do
      @thumb = ImageThumbnailFile.create(title: "thumb", core_record: core)
      core.thumbnail.should == @thumb
    end
  end

  describe "Custom relationships" do
    before :all do
      @one   = FactoryGirl.create(:bills_complete_file)
      @two   = FactoryGirl.create(:bills_complete_file)
      @three = FactoryGirl.create(:bills_complete_file)
      @four  = FactoryGirl.create(:root_collection)
    end

    def save_all
      @one.save! ; @two.save! ; @three.save!
    end

    it "can assign additional parents" do
      @one.also_member_of = [@four]
      @one.save!

      @one.also_member_of.should =~ [@four]
      @one.rels_ext.content.should include("<drs:isAlsoMemberOf")
    end

    it "can assign and find codebooks" do
      @one.codebook_for = [@three]
      @two.codebook_for = [@three]

      save_all

      @one.codebook_for.should =~ [@three]
      @one.rels_ext.content.should include("<drs:isCodebookFor")

      @three.codebook_ids.should =~ [@one.pid, @two.pid]
    end

    it "can assign and find datasets" do
      @one.dataset_for = [@three]
      @two.dataset_for = [@three]

      save_all

      @one.dataset_for.should =~ [@three]
      @one.rels_ext.content.should include ("<drs:isDatasetFor")

      @three.dataset_ids.should =~ [@one.pid, @two.pid]
    end

    it "can assign and find figures" do
      @one.figure_for = [@three]
      @two.figure_for = [@three]

      save_all

      @one.figure_for.should =~ [@three]
      @one.rels_ext.content.should include ("<drs:isFigureFor")

      @three.figure_ids.should =~ [@one.pid, @two.pid]
    end

    it "can assign and find instructional materials" do
      @one.instructional_material_for = [@three]
      @two.instructional_material_for = [@three]

      save_all

      @one.instructional_material_for.should =~ [@three]
      @one.rels_ext.content.should include("<drs:isInstructionalMaterialFor")

      @three.instructional_material_ids.should =~ [@one.pid, @two.pid]
    end

    it "can assign and find supplemental materials" do
      @one.supplemental_material_for = [@three]
      @two.supplemental_material_for = [@three]

      save_all

      @one.supplemental_material_for.should =~ [@three]
      @one.rels_ext.content.should include("<drs:isSupplementalMaterialFor")

      @three.supplemental_material_ids.should =~ [@one.pid, @two.pid]
    end

    it "can assign and find transcriptions" do
      @one.transcription_of = [@three]
      @two.transcription_of = [@three]

      save_all

      @one.transcription_of.should =~ [@three]
      @one.rels_ext.content.should include("<drs:isTranscriptionOf")

      @three.transcription_ids.should =~ [@one.pid, @two.pid]
    end

    after :all do
      @one.destroy ; @two.destroy ; @three.destroy ; @four.destroy
    end
  end

  describe 'tombstone file' do
    shared_examples_for "successful tombstone" do
      it "sets properties.tombstoned to true" do
        @c1_gf.properties.tombstoned should = 'true'
      end

      it "sets solr doc tombstoned_ssi to true" do
        @solr["tombstoned_ssi"].should == 'true'
      end

      it "sets tombstoned? to true" do
        @c1_gf.tombstoned?.should be true
      end

      after(:each) do
        @c1_gf.destroy
        @child_one.destroy
        @root.destroy
      end
    end

    context "without tombstone reason" do
      before(:each) do
        @root = Collection.create(title: "Root")
        @child_one = Collection.create(title: "Child One", parent: @root)
        @c1_gf = CoreFile.create(title: "Core File One", parent: @child_one, depositor: "nobody@nobody.com")
        @c1_gf.tombstone
        @c1_gf.save!
        @solr =  @c1_gf.to_solr
      end

      it "has no mods accessCondition" do
        @c1_gf.mods.access_condition.should == []
      end

      it "has no tombstone reason" do
        @c1_gf.tombstone_reason.should == []
      end

      it_should_behave_like "successful tombstone"
    end

    context "with tombstone reason" do
      before(:each) do
        @root = Collection.create(title: "Root")
        @child_one = Collection.create(title: "Child One", parent: @root)
        @c1_gf = CoreFile.create(title: "Core File One", parent: @child_one, depositor: "nobody@nobody.com")
        @c1_gf.tombstone("Removed at the request of Northeastern University")
        @c1_gf.save!
        @solr = SolrDocument.new(@c1_gf.to_solr)
      end

      it "has tombstone message" do
        @c1_gf.tombstone_reason.should == "Removed at the request of Northeastern University"
        @solr.tombstone_reason.should == "Removed at the request of Northeastern University"
      end

      it "has mods accessCondition" do
        @c1_gf.mods.access_condition.should == ["Removed at the request of Northeastern University"]
      end

      it "has correct mods accessCondition type" do
        @c1_gf.mods.access_condition(0).type.should == ["suppressed"]
      end

      it_should_behave_like "successful tombstone"
    end
  end

  describe 'revive file' do
    shared_examples_for "successful revive" do
      it "sets properties.tombstoned to empty" do
        @c1_gf.revive
        @c1_gf.properties.tombstoned should = ''
      end

      it "sets solr doc tombstoned_ssi to empty" do
        @c1_gf.revive
        @c1_gf.save!
        @solr =  @c1_gf.to_solr
        @solr["tombstoned_ssi"].should be nil
      end

      it "sets tombstoned? to false" do
        @c1_gf.revive
        @c1_gf.tombstoned?.should be false
      end

      it "returns false if parent is tombstoned" do
        @parent.tombstone
        @parent.save!
        @c1_gf.revive.should be false
      end

      after(:each) do
        @c1_gf.destroy
        @parent.destroy
        @root.destroy
      end
    end

    context "with tombstone reason" do
      before(:each) do
        @root = Collection.create(title: "Root")
        @parent = Collection.create(title: "Child One", parent: @root)
        @c1_gf = CoreFile.create(title: "Core File One", parent: @parent, depositor: "nobody@nobody.com")
        @c1_gf.tombstone("Removed at the request of Northeastern University")
        @c1_gf.save!
        @solr =  @c1_gf.to_solr
      end
      it "has no mods accessCondition" do
        @c1_gf.revive
        @c1_gf.mods.access_condition.should == []
      end

      it "has no tombstone reason" do
        @c1_gf.revive
        @c1_gf.tombstone_reason.should == []
      end

      it_should_behave_like "successful revive"
    end

    context "without tombstone reason" do
      before(:each) do
        @root = Collection.create(title: "Root")
        @parent = Collection.create(title: "Child One", parent: @root)
        @c1_gf = CoreFile.create(title: "Core File One", parent: @parent, depositor: "nobody@nobody.com")
        @c1_gf.tombstone
        @c1_gf.save!
        @solr =  @c1_gf.to_solr
      end

      it_should_behave_like "successful revive"
    end
  end
end
