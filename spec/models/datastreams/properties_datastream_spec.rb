require 'spec_helper'

describe PropertiesDatastream do

  let(:properties) { PropertiesDatastream.new }

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

  describe "Incomplete state" do
    it "is false on initialization" do
      properties.incomplete?.should be false
    end

    it "can be toggled to true using the appropriate helper" do
      properties.tag_as_incomplete
      properties.incomplete?.should be true
    end

    it "can be toggled to false using the appropriate helper" do
      properties.tag_as_incomplete
      properties.incomplete?.should be true

      properties.tag_as_completed
      properties.incomplete?.should be false
    end
  end

  describe "stream only state" do
    it "is false on initialization" do
      properties.stream_only?.should be false
    end

    it "can be toggled to true using the appropriate helper" do
      properties.tag_as_stream_only
      properties.stream_only?.should be true
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

  describe "Personal collection type" do
    it "returns nil when called on anything other than a personal collection" do
      properties.smart_collection_type = []
      properties.get_smart_collection_type.should be nil
    end

    it "returns the type of the personal collection when the field is defined" do
      properties.smart_collection_type = "User Root"
      properties.get_smart_collection_type.should == "User Root"
    end
  end
end
