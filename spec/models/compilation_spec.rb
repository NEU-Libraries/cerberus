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
    Compilation.find(:all).each do |compilation| 
      compilation.destroy 
    end
  end 

  describe "Adding entries" do 
    let(:member_entries) { compilation.relationships(:has_member)}

    it "can be done via saved NuCoreFile object" do 
      compilation.add_entry(file) 

      member_entries.should have_entries_for([file.pid])  
    end

    it "can be done via the pid of a NuCoreFile object" do 
      compilation.add_entry(file.pid) 

      member_entries.should have_entries_for([file.pid]) 
    end
  end

  describe "Removing entries" do

    it "can be done via saved NuCoreFile object" do 
      compilation.add_entry(file)
      compilation.add_entry(file_two) 

      compilation.relationships(:has_member).should have_entries_for([file.pid, file_two.pid]) 

      compilation.remove_entry(file) 

      compilation.relationships(:has_member).should have_entries_for([file_two.pid]) 
    end

    it "can be done via the pid of a NuCoreFile object" do 
      compilation.add_entry(file)
      compilation.add_entry(file_two) 

      compilation.relationships(:has_member).should have_entries_for([file.pid, file_two.pid]) 

      compilation.remove_entry(file.pid)

      compilation.relationships(:has_member).should have_entries_for([file_two.pid]) 
    end
  end

  describe "Entry retrieval" do 

    it "can return an array of NuCoreFile objects" do 
      compilation.add_entry(file) 
      compilation.add_entry(file_two) 

      gf_array = [file, file_two]

      compilation.entries.should =~ gf_array 
    end

    it "can return an array of NuCoreFile PIDS" do
      compilation.add_entry(file) 
      compilation.add_entry(file_two) 

      gf_pid_array = [file.pid, file_two.pid] 

      compilation.entry_ids.should =~ gf_pid_array 
    end 
  end

  describe "Removing dead links" do 

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


  describe "User based lookup" do 

    it "returns all compilations associated with the given user" do 
      a = FactoryGirl.create(:bills_compilation)

      Compilation.users_compilations(bill).length.should == 1 
    end
  end 
end