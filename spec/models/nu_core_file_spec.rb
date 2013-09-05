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
    let(:core) { NuCoreFile.new }

    it "succeeds when the user has edit permissions on the targetted collection" do 
      core.set_parent(bills_collection, bill).should be true 
      core.parent.should == bills_collection 
    end

    it "fails when the user does not have edit permissions on the targetted collection" do 
      expect{ set_parent(bills_collection, bo) }.to raise_error
    end

    it "only allows a single entry" do 
      core.set_parent(bills_collection, bill).should be true 
      core.set_parent(bills_collection_two, bill).should be true 

      core.parent.should == bills_collection_two 
      core.relationships(:is_member_of).length.should == 1
    end
  end
end


