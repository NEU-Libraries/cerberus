require 'spec_helper' 

describe NuModsCollectionDatastream do 
  before :all do 
    @mods = NuModsCollectionDatastream.new() 
  end

  subject { @mods } 

  it { should respond_to(:to_xml) } 

  describe "Element access do" do 
    before do 
      @mods.title_info.title = "My title" 
      @mods.abstract = "This is a test object created for testing" 
      @mods.identifier = "neu:123abc" 
    end

    it "Has set the title correctly" do 
      @mods.title_info.title.first.should == "My title" 
    end

    it "Has the abstract set correctly" do 
      @mods.abstract.first.should == "This is a test object created for testing" 
    end

    it "Has the identifier set correctly" do 
      @mods.identifier.first.should == "neu:123abc" 
    end
  end

  describe "Proxy functionality" do 
    before do 
      @mods.title = "My title II" 
    end

    it "Has set the title via the proxy correctly" do 
      @mods.title_info.title.first.should == "My title II" 
    end
  end
end
