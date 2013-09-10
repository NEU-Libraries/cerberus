require 'spec_helper' 

describe Drs::Rights::InheritedRestrictions do 
  let(:child) { FactoryGirl.create(:valid_owned_by_bill) } 
  let(:parent) { FactoryGirl.create(:root_collection) } 

  describe "Inherited restrictions" do 

    it "allow all mass permissions for a public parent." do 
      parent.mass_permissions = 'public'
      parent.save! 

      child.parent = parent 

      child.valid_mass_permissions.should == ['public', 'registered', 'private'] 
    end

    it "allow registered and private for a parent with perm 'registered'" do 
      parent.mass_permissions = 'registered'
      parent.save! 

      child.parent = parent 

      child.valid_mass_permissions.should == ['registered', 'private'] 
    end

    it "allow private for a parent set to private" do 
      parent.mass_permissions = 'private'
      parent.save! 

      child.parent = parent 

      child.valid_mass_permissions.should == ['private'] 
    end
  end
end