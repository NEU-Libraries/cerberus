require 'spec_helper' 

describe NuModsCollectionDatastream do 
  before :all do 
    @mods = NuModsCollectionDatastream.new() 
  end

  subject { @mods } 

  it { should respond_to(:to_xml) } 

  describe "Element access do" do 
    before do 
      @mods.mods_title_info.mods_title = "My title" 
      @mods.mods_abstract = "This is a test object created for testing" 
      @mods.mods_identifier = "neu:123abc" 
    end

    it "Has set the title correctly" do 
      @mods.mods_title_info.mods_title.first.should == "My title" 
    end

    it "Has the abstract set correctly" do 
      @mods.mods_abstract.first.should == "This is a test object created for testing" 
    end

    it "Has the identifier set correctly" do 
      @mods.mods_identifier.first.should == "neu:123abc" 
    end
  end

  describe "Proxy functionality" do 
    before do 
      @mods.mods_title = "My title II" 
    end

    it "Has set the title via the proxy correctly" do 
      @mods.mods_title_info.mods_title.first.should == "My title II" 
    end
  end
end
