require 'spec_helper' 

describe GenericFile do 

  describe "In progress state" do
    let(:bill) { FactoryGirl.create(:bill) } 
    let(:bo) { FactoryGirl.create(:bo) } 
    let(:gf) { GenericFile.new } 

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
end


