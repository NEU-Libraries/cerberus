require 'spec_helper' 

describe NuCollection do 

  before do 
    @collection = NuCollection.new() 
  end

  subject { @collection } 

  it { should respond_to(:nu_title) } 
  it { should respond_to(:nu_description) } 
  it { should respond_to(:nu_identifier) } 
  it { should respond_to(:mods_title) } 
  it { should respond_to(:mods_abstract) } 
  it { should respond_to(:mods_identifier) }
  it { should respond_to(:nu_title_display) } 
  it { should respond_to(:nu_description_display) } 
  it { should respond_to(:mods_title_display) } 
  it { should respond_to(:mods_abstract_display) } 

  describe "Delegations" do 
    before do 
      @collection.nu_title = "Nu Title" 
      @collection.nu_description = "My Nu Collection" 
      @collection.nu_identifier = "123456" 
      @collection.mods_title = "Mods Title" 
      @collection.mods_abstract = "Mods Abstract"
      @collection.mods_identifier = "Mods Identifier" 
    end

    it "Sets the oaidc title field" do 
      @collection.datastreams['oaidc'].nu_title.first.should == "Nu Title"  
    end

    it "Sets the oaidc description field" do 
      @collection.datastreams['oaidc'].nu_description.first.should == "My Nu Collection" 
    end

    it "Sets the oaidc identifier field" do 
      @collection.datastreams['oaidc'].nu_identifier.first.should == "123456" 
    end

    it "Sets the mods title field" do 
      @collection.datastreams['mods'].mods_title.first.should == "Mods Title" 
    end

    it "Sets the mods abstract field" do 
      @collection.datastreams['mods'].mods_abstract.first.should == "Mods Abstract" 
    end

    it "Sets the mods identifier field" do 
      @collection.datastreams['mods'].mods_identifier.first.should == "Mods Identifier" 
    end

    describe "Display methods" do 

      it "Grabs the oaidc title element correctly" do 
        @collection.nu_title_display.should == "Nu Title" 
      end

      it "Grabs the oaidc description element correctly" do 
        @collection.nu_description_display.should == "My Nu Collection" 
      end

      it "Grabs the mods title element correctly" do 
        @collection.mods_title_display.should == "Mods Title" 
      end

      it "Grabs the mods abstract element correctly" do 
        @collection.mods_abstract_display.should == "Mods Abstract" 
      end
    end
  end
end 