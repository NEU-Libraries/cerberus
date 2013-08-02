require 'spec_helper' 

describe NortheasternDublinCoreDatastream do 

  before do 
    @ndbc = NortheasternDublinCoreDatastream.new
  end

  subject { @ndbc } 

  it { should respond_to(:to_xml) } 
  it { should respond_to(:nu_title) } 
  it { should respond_to(:nu_description) } 
  it { should respond_to(:nu_type) } 
  it { should respond_to(:nu_identifier) } 

  describe "Setting fields" do 

    before do 
      @ndbc.nu_title = "My title" 
      @ndbc.nu_description = "My description" 
      @ndbc.nu_type = "My type" 
      @ndbc.nu_identifer = "My identifier" 
    end

    it "Has the assigned nu_description" do 
      @ndbc.nu_title.should == "My title" 
    end

    it "Has the assigned description" do 
      @ndbc.nu_description.should == "My description" 
    end

    it "Has the assigned nu_type" do 
      @ndbc.nu_type.should == "My type" 
    end

    it "Has the assigned nu_identifier" do 
      @ndbc.nu_identifier.should == "My identifier" 
    end
  end
end

