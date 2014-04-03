require 'spec_helper'

describe SliderMaxCalculator do

  describe "'s compute method" do

    it "returns the width for landscape images" do
      file = Rails.root.join('spec', 'fixtures', 'files', 'test_pic.jpeg')
      SliderMaxCalculator.compute(file).should == 259
    end

    it "returns the height for portrait images" do
      file = Rails.root.join('spec', 'fixtures', 'files', 'image.png')
      SliderMaxCalculator.compute(file).should == 588
    end
  end
end
