require 'spec_helper'

describe "Metadata" do
  let(:compilation) { Compilation.new }
  let(:collection) { Collection.new }
  let(:core_file) { CoreFile.new }

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
        collection.keywords = keywords

        collection.keywords.should == keywords
      end
    end

    describe "of creators" do
      let(:fns) { ["Will", "James"] }
      let(:lns) { ["Jackson", "Bond"] }
      let(:cns) { ["Org One", "Org Two"] }
      let(:hsh) { {
                    'first_names' => fns,
                    'last_names'  => lns,
                    'corporate_names' => cns
                } }

      it "succeeds for objects with only a DC datastream" do
        compilation.creators = hsh

        compilation.creators.should =~ ["Will Jackson", "James Bond", "Org One", "Org Two"]
      end

      it "succeeds for objects with DC and MODS datastreams" do
        collection.creators = hsh

        # Ensure the DC record set correctly
        collection.creators.should =~ ["Will Jackson", "James Bond", "Org One", "Org Two"]

        # Ensure the MODS record set correctly
        collection.personal_creators.should =~ [{first: "Will", last: "Jackson"}, {first: "James", last: "Bond"}]
        collection.corporate_creators.should =~ ["Org One", "Org Two"]
      end
    end

    describe "of depositor" do
      let(:user) { User.new(nuid: '000000001') }

      it "succeeds for objects with a properties datastream" do
        compilation.depositor = '000000001'
        compilation.depositor.should == '000000001'
      end

      it "additionally assigns edit permissions to the depositor" do
        core_file.depositor = '000000001'
        core_file.save!

        user.can?(:edit, core_file).should be true
      end
    end

    describe "of proxy uploader" do
      let(:proxier) { User.new(nuid: '000333222') }

      it "succeeds for objects with a properties datastream" do
        compilation.proxy_uploader = '000333222'
        compilation.proxy_uploader.should == '000333222'
      end

      it "doesn't assign edit permissions to the proxy uploader" do
        core_file.depositor      = '000000001'
        core_file.proxy_uploader = '000333222'
        core_file.save!

        proxier.can?(:edit, core_file).should be false
      end
    end

    describe "of canon status" do

      it "succeeds for objects with a properties datastream" do
        compilation.canonize

        compilation.canonical?.should be true
      end

      it "allows revocation of canon status as well" do
        compilation.canonize
        compilation.canonical?.should be true

        compilation.uncanonize
        compilation.canonical?.should be false
      end
    end

    describe "of smart_collection_type" do
      it "succeeds for objects with a properties datastream" do
        collection.smart_collection_type = "personal collection type"
        collection.smart_collection_type.should == 'personal collection type'
      end
    end
  end

  describe "predicates" do
    it "allow us to check if something is a personal collection" do
      collection.smart_collection_type = 'miscellany'
      collection.is_smart_collection?.should be true

      collection.smart_collection_type = []
      collection.is_smart_collection?.should be false
    end

    it "allow us check if something is canon" do
      compilation.canonize
      compilation.canonical?.should be true

      compilation.uncanonize
      compilation.canonical?.should be false
    end
  end
end
