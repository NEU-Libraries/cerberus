require 'spec_helper' 

describe ContentCreationJob do

  describe "With Image File" do 
    before :all do 
      @user = FactoryGirl.create(:bill) 
      @core = FactoryGirl.create(:bills_complete_file) 
      path = "#{Rails.root}/spec/fixtures/test_pic.jpeg" 
      @newpath = "#{Rails.root}/tmp/test_pic.jpeg" 
      FileUtils.copy(path, @newpath) 
      filename = 'test_pic.jpeg' 
      @imagefile = ContentCreationJob.new(@core.pid, @newpath, filename, @user.id).run 
    end

    after(:all) { @user.destroy && @core.destroy } 

      it "Creates an ImageMasterFile object in fedora" do 
        @imagefile.should be_an_instance_of ImageMasterFile 
      end

      it "Loads some content into that image master file object" do 
        @imagefile.content.should_not be nil 
      end

      it "Labels the content appropriately" do 
        @imagefile.content.label.should == "test_pic.jpeg" 
      end

      it "Titles the object appropriately" do 
        @imagefile.title.should == "test_pic.jpeg" 
      end
    end 

  describe "With zip file" do
    before :all do
      @user = FactoryGirl.create(:bill)
      @core = FactoryGirl.create(:bills_complete_file)  
      path = "#{Rails.root}/spec/fixtures/zip.ott" 
      @newpath = "#{Rails.root}/tmp/zip_test.ott" 
      FileUtils.copy(path, @newpath) 
      filename = 'zip_test.ott' 
      @zipfile = ContentCreationJob.new(@core.pid, @newpath, filename, @user.id).run 
    end

    after(:all) { @user.destroy && @core.destroy } 

    it "Creates a zip file object in Fedora." do 
      @zipfile.should be_an_instance_of ZipFile 
    end

    it "Loads some content into the zipfile object" do 
      @zipfile.content.should_not be nil 
    end

    it "Labels the zipfile object with the original file format" do 
      @zipfile.title.should == "zip_test.ott" 
    end

    it "Labels the zipped object as a zip archive" do 
      @zipfile.content.label.should == "zip_test.zip" 
    end

    it "Eliminates the temp file after use" do 
      File.exists?(@newpath).should be false 
    end
  end
end