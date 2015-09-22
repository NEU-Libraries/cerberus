require 'spec_helper'

describe Compilation do
  let(:bill) { FactoryGirl.create(:bill) }
  let(:compilation) { FactoryGirl.create(:compilation) }
  let(:file) { FactoryGirl.create(:bills_complete_file) }
  let(:file_two) { FactoryGirl.create(:bills_complete_file) }

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


      result = compilation.entries

      expect(result.map{ |x| x["id"] }).to match_array [file.pid, file_two.pid]
      expect(result.all? { |x| x.class == SolrDocument}).to be true
    end

    it "can return an array of CoreFile PIDS" do
      compilation.add_entry(file)
      compilation.add_entry(file_two)

      gf_pid_array = [file.pid, file_two.pid]

      compilation.entry_ids.should =~ gf_pid_array
    end
  end

  describe "Removing dead links" do
    it "cleans out tombstoned objects" do
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
    it "cleans out deleted objects" do
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
  end

  describe "Represents the compilation attributes as JSON" do
    it "responds to_json in the model" do

      compilation.add_entry(file)
      compilation.add_entry(file_two)
      compilation_json = compilation.to_json

      parsed = JSON.parse(compilation_json);
      parsed.length.should > 0;

      parsed["title"].should == compilation.title
      parsed["entries"][0].should == compilation.entries[0].pid
      parsed["entries"][1].should == compilation.entries[1].pid
    end
  end
  describe "User based lookup" do

    it "returns all compilations associated with the given user" do
      a = FactoryGirl.create(:bills_compilation)

      Compilation.users_compilations(bill).length.should == 1
    end
  end
end
