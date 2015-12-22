require 'spec_helper'

describe Compilation do
  let(:bill) { FactoryGirl.create(:bill) }
  let(:compilation) { FactoryGirl.create(:compilation) }
  let(:file) { FactoryGirl.create(:bills_complete_file) }
  let(:file_two) { FactoryGirl.create(:bills_complete_file) }
  let(:bills_collection) { FactoryGirl.create(:valid_owned_by_bill) }
  let(:bills_collection_2) { FactoryGirl.create(:valid_owned_by_bill) }

  subject { compilation }

  it { should respond_to(:title) }
  it { should respond_to(:identifier) }
  it { should respond_to(:add_entry) }
  it { should respond_to(:remove_entry) }

  after(:each) do
    ActiveFedora::Base.find(:all).each do |file|
      file.destroy
    end
  end

  describe "Adding entries" do
    let(:member_entries) { compilation.relationships(:has_member)}

    it "can be done via saved CoreFile object" do
      compilation.add_entry(file)

      member_entries.should have_entries_for([file.pid])
    end

    it "can be done via the pid of a CoreFile object" do
      compilation.add_entry(file.pid)

      member_entries.should have_entries_for([file.pid])
    end

    it "can be done via saved Collection object" do
      compilation.add_entry(bills_collection)

      member_entries.should have_entries_for([bills_collection.pid])
    end

    it "can be done via the pid of a Collection object" do
      compilation.add_entry(bills_collection.pid)

      member_entries.should have_entries_for([bills_collection.pid])
    end
  end

  describe "Removing entries" do

    it "can be done via saved CoreFile object" do
      compilation.add_entry(file)
      compilation.add_entry(file_two)

      compilation.relationships(:has_member).should have_entries_for([file.pid, file_two.pid])

      compilation.remove_entry(file)

      compilation.relationships(:has_member).should have_entries_for([file_two.pid])
    end

    it "can be done via the pid of a CoreFile object" do
      compilation.add_entry(file)
      compilation.add_entry(file_two)

      compilation.relationships(:has_member).should have_entries_for([file.pid, file_two.pid])

      compilation.remove_entry(file.pid)

      compilation.relationships(:has_member).should have_entries_for([file_two.pid])
    end

    it "can be done via the pid of a CoreFile object" do
      compilation.add_entry(bills_collection)
      compilation.add_entry(bills_collection_2)

      compilation.relationships(:has_member).should have_entries_for([bills_collection.pid, bills_collection_2.pid])

      compilation.remove_entry(bills_collection.pid)

      compilation.relationships(:has_member).should have_entries_for([bills_collection_2.pid])
    end

    it "can be done via saved Collection object" do
      compilation.add_entry(bills_collection)
      compilation.add_entry(bills_collection_2)

      compilation.relationships(:has_member).should have_entries_for([bills_collection.pid, bills_collection_2.pid])

      compilation.remove_entry(bills_collection)

      compilation.relationships(:has_member).should have_entries_for([bills_collection_2.pid])
    end
  end

  describe "Entry retrieval" do
    it "returns the empty array when no items have been added" do
      expect(compilation.entries).to eq []
    end

    it "returns an empty array when pids have been requested on an empty comp" do
      expect(compilation.entry_ids).to eq []
    end

    it "can return an array of SolrDocument objects" do
      compilation.add_entry(file)
      compilation.add_entry(file_two)
      compilation.add_entry(bills_collection)
      compilation.save!

      comp_pid = compilation.pid
      compilation = Compilation.find(comp_pid)
      result = compilation.entries

      expect(result.map{ |x| x["id"] }).to match_array [file.pid, file_two.pid, bills_collection.pid]
      expect(result.all? { |x| x.class == SolrDocument}).to be true
    end

    it "can return an array of PIDS" do
      compilation.add_entry(file)
      compilation.add_entry(file_two)
      compilation.add_entry(bills_collection)
      gf_pid_array = [file.pid, file_two.pid, bills_collection.pid]

      compilation.entry_ids.should =~ gf_pid_array
    end
  end

  describe "Removing dead links" do
    it "cleans out tombstoned corefiles" do
      root = Collection.create(title: "Root")
      file = CoreFile.create(title: "Core File One", parent: root, depositor: "nobody@nobody.com")
      file.save!
      compilation.add_entry(file)
      compilation.add_entry(file_two)
      compilation.save!

      file_pid = file.pid
      file.tombstone
      file.save!

      comp_pid = compilation.pid
      compilation = Compilation.find(comp_pid)
      compilation.remove_dead_entries.should == [file_pid]

      compilation.entry_ids.should =~ [file_two.pid]
    end

    it "cleans out tombstoned collections" do
      col1 = Collection.create(title: "Col1")
      col2 = Collection.create(title: "Col2")
      compilation.add_entry(col1)
      compilation.add_entry(col2)
      compilation.save!

      col1_pid = col1.pid
      col1.tombstone
      col1.save!

      comp_pid = compilation.pid
      compilation = Compilation.find(comp_pid)
      compilation.remove_dead_entries.should == [col1_pid]

      compilation.entry_ids.should =~ [col2.pid]
    end

    it "cleans out deleted corefiles" do
      compilation.add_entry(file)
      compilation.add_entry(file_two)
      compilation.save!

      file_pid = file.pid
      file.delete

      comp_pid = compilation.pid
      compilation = Compilation.find(comp_pid)
      compilation.remove_dead_entries.should == [file_pid]

      compilation.entry_ids.should =~ [file_two.pid]
    end

    it "cleans out deleted collections" do
      compilation.add_entry(bills_collection)
      compilation.add_entry(bills_collection_2)
      compilation.save!

      col_pid = bills_collection.pid
      bills_collection.delete

      comp_pid = compilation.pid
      compilation = Compilation.find(comp_pid)
      compilation.remove_dead_entries.should == [col_pid]

      compilation.entry_ids.should =~ [bills_collection_2.pid]
    end
  end

  describe "Represents the compilation attributes as JSON" do
    it "responds to_json in the model" do

      compilation.add_entry(file)
      compilation.add_entry(file_two)
      compilation.add_entry(bills_collection)
      compilation.save!

      compilation_json = compilation.to_json

      parsed = JSON.parse(compilation_json);
      parsed.length.should > 0;
      comp_pid = compilation.pid
      compilation = Compilation.find(comp_pid)
      entries = compilation.entries

      parsed["title"].should == compilation.title
      parsed["entries"][0].should == entries[0]['id']
      parsed["entries"][1].should == entries[1]['id']
      parsed["entries"][2].should == entries[2]['id']
    end
  end
end
