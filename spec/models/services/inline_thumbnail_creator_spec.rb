require 'spec_helper' 

describe InlineThumbnailCreator do 
  let(:collection) { FactoryGirl.create(:collection) }

  before(:all) do 
    @gif = Rails.root.join('spec', 'fixtures', 'files', 'image.gif').to_s
  end

  describe "create_thumbnail" do
    before(:each) do 
      InlineThumbnailCreator.new(collection, @gif, 'thumbnail').create_thumbnail
    end

    it "generates a thumbnail from the specified string path" do 
      collection.thumbnail.label.should == File.basename(@gif) 
      collection.thumbnail.content.should_not be_nil 
    end

    it "doesn't save the object" do
      collection.reload
      collection.thumbnail.label.should == "File Datastream" 
      collection.thumbnail.content.should be_nil 
    end
  end

  describe "create_thumbnail_and_save" do 
    before(:each) do 
      InlineThumbnailCreator.new(collection, @gif, 'thumbnail').create_thumbnail_and_save
    end

    it "does save the object" do 
      collection.reload
      collection.thumbnail.label.should == File.basename(@gif) 
      collection.thumbnail.content.should_not be_nil 
    end
  end
end
