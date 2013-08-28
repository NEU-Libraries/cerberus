require 'spec_helper' 

describe DrsPropertiesDatastream do 
  describe "In progress state" do 
    
    let(:properties) { DrsPropertiesDatastream.new } 

    it "is false on initialization" do 
      properties.in_progress?.should be false 
    end

    it "can be toggled to true using the appropriate helper" do 
      properties.tag_as_in_progress 
      properties.in_progress?.should be true 
    end

    it "can be toggled to false using the appropriate helper" do 
      properties.tag_as_in_progress
      properties.in_progress?.should be true 

      properties.tag_as_completed
      properties.in_progress?.should be false 
    end
  end
end