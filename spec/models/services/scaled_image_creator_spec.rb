require 'spec_helper'

describe ScaledImageCreator do

  def set_context(klass)
    @current = @root.content_objects.find { |x| x.instance_of? klass }
    @klass = klass
  end

  def count_derivative(klass)
    @root.content_objects.count { |x| x.instance_of? klass }
  end

  def content_label_from_master
    return "#{@master.label.chomp(File.extname(@master.label))}.jpg"
  end

  shared_examples_for "image creation" do

    it "creates a single image file record" do
      @current.should_not be nil
      count_derivative(@klass).should == 1
    end

    it "attaches content to the image record" do
      @current.content.content.should_not be_nil
    end

    it "attaches the correct label" do
      @current.content.label.should == content_label_from_master
    end
  end

  context "Without preexisting scaled image objects," do
    before :all do
      @master = FactoryGirl.create(:image_master_file)
      @root = @master.core_record

      ScaledImageCreator.new(0.3, 0.6, 0.9, @master).create_scaled_images
    end

    after(:all) { @root.destroy }

    describe "small image creation" do
      before(:all) { set_context ImageSmallFile }

      it_should_behave_like "image creation"
    end

    describe "medium image creation" do
      before(:all) { set_context ImageMediumFile }

      it_should_behave_like "image creation"
    end

    describe "large image creation" do
      before(:all) { set_context ImageLargeFile }

      it_should_behave_like "image creation"
    end
  end
end
