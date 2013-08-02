require 'spec_helper' 

describe NortheasternDublinCoreDatastream do 

  before do 
    @ndbc = NortheasternDublinCoreDatastream.new
  end

  subject { @ndbc } 

  it { should respond_to(:to_xml) }  

  describe "Setting fields" do 

    before do 
      @ndbc.nu_title = "My title" 
      @ndbc.nu_description = "My description" 
      @ndbc.nu_type = "My type" 
      @ndbc.nu_identifier = "My identifier" 
    end

    it "Has the assigned nu_description" do
      @ndbc.nu_title.first.should == "My title" 
    end

    it "Has the assigned description" do 
      @ndbc.nu_description.first.should == "My description" 
    end

    it "Has the assigned nu_type" do 
      @ndbc.nu_type.first.should == "My type" 
    end

    it "Has the assigned nu_identifier" do 
      @ndbc.nu_identifier.first.should == "My identifier" 
    end
  end
end

