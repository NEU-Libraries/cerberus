require 'spec_helper' 

describe "Metadata" do 
  let(:compilation) { Compilation.new } 
  let(:core_file) { NuCoreFile.new } 
  let(:collection) { NuCollection.new }

  describe "assignment" do 
    describe "of title" do 
      it "works for objects with only a DC datastream." do 
        compilation.title = "My Title" 
        compilation.title.should == "My Title" 
      end

      it "works for objects with DC and MODS datastreams" do 
        collection.title = "My Title Two" 
        collection.title.should == "My Title Two" 
      end

      it "works for objects with DC, MODS, and descMetadata datastreams" do 
        core_file.title = "My Title Three" 
        core_file.title.should == "My Title Three" 
      end
    end

    describe "of identifier" do 
      it "works for objects with with only a DC datastream" do 
        compilation.identifier = "neu:whatever" 
        compilation.identifier.should == "neu:whatever" 
      end

      it "works for objects with DC and MODS datastreams" do 
        collection.identifier = "neu:whatever" 
        collection.identifier.should == "neu:whatever" 
      end

      it "works for objects with DC, MODS, and descMetadata datastreams" do 
        core_file.identifier = "neu:three" 
        core_file.identifier.should == "neu:three" 
      end
    end

    describe "of description" do 
      it "works for objects with only a DC datastream" do 
        compilation.description = "The description." 
        compilation.description.should == "The description." 
      end

      it "works for objects with DC and MODS datastreams" do 
        collection.description = "The description two." 
        collection.description.should == "The description two." 
      end

      it "works for objects with DC, MODS, and descMetadata datastreams" do 
        core_file.description = "The description three" 
        core_file.description.should == "The description three" 
      end
    end

    describe "of date issued" do 
      it "works for objects with only a DC datastream" do 
        compilation.date_of_issue = Date.today.to_s 

        compilation.date_of_issue.should == Date.today.to_s 
      end

      it "works for objects with DC and MODS datastreams" do 
        collection.date_of_issue = Date.today.to_s 

        collection.date_of_issue.should == Date.today.to_s 
      end
    end

    describe "of keywords" do
      let(:keywords) { ["one", "two", "three" ] }

      it "works for objects with only a DC datastream" do 
        compilation.keywords = keywords 

        compilation.keywords.should == keywords 
      end

      it "succeeds for objects with DC and MODS datastream" do 
        core_file.keywords = keywords

        core_file.keywords.should == keywords 
      end
    end

    describe "of corporate creators" do 
      let(:cc) { ["cone", "ctwo"] } 

      it "fails for objects with no MODS datastream" do 
        expect { compilation.corporate_creators = cc }.to raise_error
      end

      it "succeeds for objects with a MODS datastream" do 
        collection.corporate_creators = cc 
        collection.corporate_creators.should == cc 
      end
    end

    describe "of personal creators" do 
      let(:assignment_hash) do 
        { 'creator_first_names' => ["Will", "Bill"], 'creator_last_names' => ["Jackson", "Backson"] }
      end  

      it "fails for objects with no MODS datastream" do 
        expect { compilation.personal_creators = assignment_hash }.to raise_error 
      end

      it "succeeds for objects with a MODS datastream" do 
        result_hash = [{first: "Will", last: "Jackson"}, {first: "Bill", last: "Backson"}]
        core_file.personal_creators = assignment_hash 
        core_file.personal_creators.should == result_hash 
      end
    end

    describe "of creators to the DC datastream" do 
      let(:fns) { ["Will", "James", "John"] } 
      let(:lns) { ["Jackson", "Bond", "Johnson"] } 
      let(:cns) { ["Org One", "Org Two"] } 

      it "succeeds for objects with a DC datastream" do 
        compilation.assign_DC_creators(fns, lns, cns) 

        compilation.DC_creators.should =~ ["Will Jackson", "James Bond", "John Johnson", "Org One", "Org Two" ] 
      end
    end

    describe "of depositor" do 
      let(:user) { User.new(email: 'example@example.com') } 

      it "succeeds for objects with a properties datastream" do 
        compilation.depositor = 'example@example.com' 
        compilation.depositor.should == 'example@example.com' 
      end

      it "additionally assigns edit permissions to the depositor" do 
        core_file.depositor = 'example@example.com'
        core_file.save! 

        user.can?(:edit, core_file).should be true 
      end
    end

    describe "of personal_folder_type" do 
      it "succeeds for objects with a properties datastream" do 
        collection.personal_folder_type = "folder type" 
        collection.personal_folder_type.should == 'folder type' 
      end
    end
  end

  describe "predicates" do 
    it "allow us to check if something is a personal collection" do 
      collection.personal_folder_type = 'miscellany' 
      collection.is_personal_folder?.should be true 

      collection.personal_folder_type = []
      collection.is_personal_folder?.should be false
    end
  end
end 