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

  describe "Adding bookmarks" do 
    let(:member_entries) { compilation.relationships(:has_member)}

    it "can be done via saved GenericFile object" do 
      compilation.add_entry(file) 

      member_entries.should have_entries_for([file.pid])  
    end

    it "can be done via the pid of a GenericFile object" do 
      compilation.add_entry(file.pid) 

      member_entries.should have_entries_for([file.pid]) 
    end
  end

  describe "Removing bookmarks" do

    it "can be done via saved GenericFile object" do 
      compilation.add_entry(file)
      compilation.add_entry(file_two) 

      compilation.relationships(:has_member).should have_entries_for([file.pid, file_two.pid]) 

      compilation.remove_entry(file) 

      compilation.relationships(:has_member).should have_entries_for([file_two.pid]) 
    end

    it "can be done via the pid of a GenericFile object" do 
      compilation.add_entry(file)
      compilation.add_entry(file_two) 

      compilation.relationships(:has_member).should have_entries_for([file.pid, file_two.pid]) 

      compilation.remove_entry(file.pid)

      compilation.relationships(:has_member).should have_entries_for([file_two.pid]) 
    end
  end
end