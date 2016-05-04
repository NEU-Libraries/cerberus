require 'spec_helper'

describe ScaledImageCreator do

  def set_context(klass)
    @current = @root.content_objects.find { |x| x.instance_of? klass }
    @klass = klass
  end

  def count_derivative(klass)
    @root.content_objects.count { |x| x.instance_of? klass }
  end

  shared_examples_for "image creation" do

    it "creates a single image file record" do
      @current.should_not be nil
      count_derivative(@klass).should == 1
    end

    it "attaches content to the image record" do
      @current.content.content.should_not be_nil
    end

  end

  context "Without preexisting scaled image objects," do
    before :all do
      @master = FactoryGirl.create(:image_master_file)
      @root = @master.core_record

      ScaledImageCreator.new(0.3, 0.6, 0.9, @master.pid).create_scaled_images
    end

    after(:all) { @root.destroy }

    describe "small image creation" do
      before(:all) { set_context(ImageSmallFile) }

      it "should have permissions like corefile" do
        @current.permissions.should == @root.permissions
      end

      it_should_behave_like "image creation"
    end

    describe "medium image creation" do
      before(:all) { set_context ImageMediumFile }

      it "should have permissions like corefile" do
        @current.permissions.should == @root.permissions
      end

      it_should_behave_like "image creation"
    end

    describe "large image creation" do
      before(:all) { set_context ImageLargeFile }

      it "should have permissions like corefile" do
        @current.permissions.should == @root.permissions
      end

      it_should_behave_like "image creation"
    end
  end

  context "with passing permissions in" do
    before :all do
      @master = FactoryGirl.create(:image_master_file)
      @root = @master.core_record
      permissions = {"CoreFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:repository:corefile"]}, "ImageSmallFile" => {"read"  => ["northeastern:drs:repository:test"], "edit" => ["northeastern:drs:repository:small"]}, "ImageLargeFile" => {"read"  => ["northeastern:drs:repository:test"], "edit" => ["northeastern:drs:repository:large"]}, "ImageMediumFile" => {"read"  => ["northeastern:drs:repository:test"], "edit" => ["northeastern:drs:repository:medium"]}, "ImageMasterFile" => {"read"  => ["northeastern:drs:repository:test"], "edit" => ["northeastern:drs:repository:master"]}}

      ScaledImageCreator.new(0.3, 0.6, 0.9, @master.pid, permissions).create_scaled_images
    end

    after(:all) { @root.destroy }

    describe "small image creation" do
      before(:all) { set_context ImageSmallFile }

      it "should set correct permissions" do
        @current.permissions.should == [{:type=>"group", :access=>"read", :name=>"northeastern:drs:repository:test"}, {:type=>"group", :access=>"edit", :name=>"northeastern:drs:repository:small"}]
      end

      it_should_behave_like "image creation"
    end

    describe "medium image creation" do
      before(:all) { set_context ImageMediumFile }

      it "should set correct permissions" do
        @current.permissions.should == [{:type=>"group", :access=>"read", :name=>"northeastern:drs:repository:test"}, {:type=>"group", :access=>"edit", :name=>"northeastern:drs:repository:medium"}]
      end

      it_should_behave_like "image creation"
    end

    describe "large image creation" do
      before(:all) { set_context ImageLargeFile }

      it "should set correct permissions" do
        @current.permissions.should == [{:type=>"group", :access=>"read", :name=>"northeastern:drs:repository:test"}, {:type=>"group", :access=>"edit", :name=>"northeastern:drs:repository:large"}]
      end

      it_should_behave_like "image creation"
    end
  end

end
