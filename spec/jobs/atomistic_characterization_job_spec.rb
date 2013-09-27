require 'spec_helper'

describe AtomisticCharacterizationJob do
  let(:image) { FactoryGirl.create(:image_master_file) } 

  describe "Images" do

    # Note that this does nothing for verifying the correctness
    # of the thumbnail in any detail.  
    it "builds an ImageThumbnailFile object when run" do
      a = AtomisticCharacterizationJob.new(image.pid) 
      a.run

      image.core_record.content_objects.length.should == 2

      b = image.core_record.content_objects
          .find { |e| e.instance_of? ImageThumbnailFile } 

      puts image.title
      puts image.keywords
      puts image.description
      
      # Check that this has done something. 
      b.should_not be nil 
      b.content.content.should_not be nil
      b.characterization.should_not be nil   
      b.depositor.should == image.depositor
      b.keywords.should =~ image.keywords 
      b.title.should == 'test_pic_thumb.jpeg'
      b.description.should == "Thumb nail for #{image.pid}"
      b.permissions.should == image.permissions
      puts b.DC.content
    end
  end
end