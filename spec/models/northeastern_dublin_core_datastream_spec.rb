require 'spec_helper' 

describe NortheasternDublinCoreDatastream do 

  let(:dublin_core) { NortheasternDublinCoreDatastream.new }

  describe "Creator assignment" do 

    let(:fns) { ["Will", "Bill"] } 
    let(:lns) { ["Jackson", "Backson"] } 
    let(:cns) { ["Org One", "Org Two"] } 

    it "disallows mismatched personal name arrays" do 
      expect { dublin_core.assign_creators([], lns, cns) }.to raise_error 
    end

    it "merges first and last names" do
      dublin_core.assign_creators(fns, lns, cns) 

      dublin_core.creator.should =~ ["Will Jackson", "Bill Backson", "Org One", "Org Two"] 
    end

    it "eliminates unneeded elements on update" do 
      dublin_core.assign_creators([], [], ["Org"])

      dublin_core.creator.should =~ ["Org"] 
    end
  end

  describe "Solrization" do 
    let(:result) { dublin_core.to_solr } 

    it "creates a sim field for dcmi type" do 
      dublin_core.nu_type = "Image" 

      result["type_sim"].should == "Image" 
    end
  end
end

