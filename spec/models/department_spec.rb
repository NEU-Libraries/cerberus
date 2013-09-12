require 'spec_helper' 

describe Department do 
  let(:department) { FactoryGirl.create(:department) } 

  describe "RELS EXT" do
    
    it "registers Department objects as derivations of NuCollection on save." do 
      department.save! 

      result = department.relationships(:is_derivation_of) 
      result.length.should be 1 
      result.first.should == 'info:fedora/afmodel:NuCollection' 

      department.destroy   
    end
  end
end