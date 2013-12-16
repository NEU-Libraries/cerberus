require 'spec_helper' 

describe ScaledImageCreator do 

  def find_derivative(klass) 
    @root.content_objects.find { |x| x.instance_of? klass } 
  end

  def count_derivative(klass) 
    @root.content_objects.count { |x| x.instance_of? klass } 
  end

  context "Without preexisting scaled image objects" do 
    let(:small)  { find_derivative ImageSmallFile } 
    let(:medium) { find_derivative ImageMediumFile }  
    let(:large)  { find_derivative ImageLargeFile } 

    before :all do 
      @img = FactoryGirl.create(:image_master_file)
      @root = @img.core_record 

      #ScaledImageCreator.new([50, 50], [100, 100], [130, 130], @img).create_scaled_images 
    end

    after(:all) { @root.destroy } 

    it "creates a single small image file" do 
      puts @root.content_objects
      small.should_not be_nil
      count_derivative(ImageSmallFile).should == 1 
    end

    it "creates a single medium image file" do 
      medium.should_not be_nil 
      count_derivative(ImageMediumFile).should == 1
    end

    it "creates a single large image file" do 
      large.should_not be_nil 
      count_derivative(ImageLargeFile).should == 1 
    end
  end
end