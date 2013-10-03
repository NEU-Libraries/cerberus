require 'spec_helper'

describe ParanoidRightsDatastream do 

  before do
    @rights_ds = ParanoidRightsDatastream.new 
  end

  subject { @rights_ds } 

  it { should respond_to(:can_read?) }
  it { should respond_to(:can_edit?) }

  describe "Specific Users and Group Permissions" do
    let(:user) { FactoryGirl.build(:user) } 
    let(:bill) { FactoryGirl.build(:bill) } 
    let(:bo)   { FactoryGirl.build(:bo) } 
    let(:gone) { FactoryGirl.build(:gone) } 
    let(:gtwo) { FactoryGirl.build(:gtwo) } 

    before do 
      @rights_ds.update_permissions('group' => { 'group_one' => 'edit', 'group_two' => 'read' }) 
      @rights_ds.update_permissions('person' => { 'bill@example.com' => 'edit', 'bo@example.com' => 'read' })
    end

    it "Does not allow user to have any permissions" do 
      @rights_ds.can_read?(user).should be false 
      @rights_ds.can_edit?(user).should be false 
    end

    it "Allows user bill@example.com full permissions" do 
      @rights_ds.can_read?(bill).should be true 
      @rights_ds.can_edit?(bill).should be true 
    end

    it "Allows user bo@example.com read permissions only" do 
      @rights_ds.can_read?(bo).should be true
      @rights_ds.can_edit?(bo).should be false 
    end

    it "Allows user gone@example.com full permissions" do 
      @rights_ds.can_read?(gone).should be true 
      @rights_ds.can_edit?(gone).should be true 
    end

    it "Allows user gtwo@example.com read permissions only" do 
      @rights_ds.can_read?(gtwo).should be true 
      @rights_ds.can_edit?(gtwo).should be false 
    end
  end

  describe "Permissions as they relate to unsigned users" do
    before do 
      @public_viewable_rds = ParanoidRightsDatastream.new 
      @public_viewable_rds.permissions({group: 'public'}, 'read')
      @public_viewable_rds.permissions({group: 'neu:staff'}, 'edit')

      @non_public_viewable_rds = ParanoidRightsDatastream.new()
      @non_public_viewable_rds.permissions({group: 'will'}, 'edit')  
    end 

    it "A user who is nil (not signed in) can read public_viewable_rds" do 
      @public_viewable_rds.can_read?(nil).should be true 
    end

    it "A user who is nil (not signed in) cannot however edit public_viewable_rds" do 
      @public_viewable_rds.can_edit?(nil).should be false 
    end

    it "A user who is nil (not signed in) cannot read non_public_viewable_rds" do 
      @non_public_viewable_rds.can_read?(nil).should be false 
    end

    it "A user who is nil (not signed in) also cannot edit non_public_viewable_rds" do 
      @non_public_viewable_rds.can_edit?(nil).should be false 
    end
  end

  describe "Embargos" do 
    let(:embargoed) { ParanoidRightsDatastream.new } 

    it "Doesn't allow non-parseable embargo dates" do 
      embargoed.embargo_release_date = "Abbbrrgggl" 
      embargoed.embargo_release_date.should == nil 
    end

    it "Is under embargo if the date is in the future" do 
      future_date = Date.tomorrow.to_s
      embargoed.embargo_release_date = future_date 
      embargoed.under_embargo?.should be true 
    end

    it "Is not under embargo if the date is in the past" do 
      embargoed.embargo_release_date = "July 9, 1321" 

      embargoed.under_embargo?.should be false 
    end

    it "Does not throw an exception even when idiotic dates are entered" do 
      embargoed.embargo_release_date = "Novtober 10, 2016" 
      embargoed.under_embargo?.should be true

      embargoed.embargo_release_date = "Julune 9, 2010" 
      embargoed.under_embargo?.should be false 
    end 
  end
end