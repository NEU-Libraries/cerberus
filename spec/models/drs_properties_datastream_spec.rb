require 'spec_helper' 

describe DrsPropertiesDatastream do

  let(:properties) { DrsPropertiesDatastream.new } 

  describe "In progress state" do 
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

  describe "Canonization" do 
    it "allows us to assert that an object is now canonical" do 
      properties.canonize 

      properties.canonical.should == ['yes'] 
    end

    it "allows us to check whether this object is canonical" do 
      properties.canonical?.should be false

      properties.canonize 

      properties.canonical?.should be true 
    end

    it "allows us to decanonize objects" do 
      properties.canonize
      properties.uncanonize 

      properties.canonical?.should be false 
    end
  end

  describe "Personal folder type" do 
    it "returns nil when called on anything other than a personal folder" do 
      properties.personal_folder_type = [] 
      properties.get_personal_folder_type.should be nil
    end

    it "returns the type of the folder when the field is defined" do 
      properties.personal_folder_type = "user root" 
      properties.get_personal_folder_type.should == "user root" 
    end
  end
end