require 'spec_helper' 

describe BookmarkSet do 
  let(:bill) { FactoryGirl.create(:bill) } 

  let(:bookmarks) { FactoryGirl.create(:bookmarks) }
  let(:file) { FactoryGirl.create(:bills_complete_file) }
  let(:file_two) { FactoryGirl.create(:bills_complete_file) } 

  subject { bookmarks } 

  it { should respond_to(:title) }
  it { should respond_to(:identifier) } 
  it { should respond_to(:add_bookmark) } 
  it { should respond_to(:remove_bookmark) }

  after(:each) do 
    BookmarkSet.find(:all).each do |bookmark| 
      bookmark.destroy 
    end
  end 

  describe "Adding bookmarks" do 
    let(:member_bookmarks) { bookmarks.relationships(:has_member)}

    it "can be done via saved GenericFile object" do 
      bookmarks.add_bookmark(file) 

      member_bookmarks.should have_bookmarks_for([file.pid])  
    end

    it "can be done via the pid of a GenericFile object" do 
      bookmarks.add_bookmark(file.pid) 

      member_bookmarks.should have_bookmarks_for([file.pid]) 
    end
  end

  describe "Removing bookmarks" do

    it "can be done via saved GenericFile object" do 
      bookmarks.add_bookmark(file)
      bookmarks.add_bookmark(file_two) 

      bookmarks.relationships(:has_member).should have_bookmarks_for([file.pid, file_two.pid]) 

      bookmarks.remove_bookmark(file)
      bookmarks.save! 

      bookmarks.relationships(:has_member).should have_bookmarks_for([file_two.pid]) 
    end

    it "can be done via the pid of a GenericFile object" do 
      bookmarks.add_bookmark(file)
      bookmarks.add_bookmark(file_two) 

      bookmarks.relationships(:has_member).should have_bookmarks_for([file.pid, file_two.pid]) 

      bookmarks.remove_bookmark(file.pid)

      bookmarks.relationships(:has_member).should have_bookmarks_for([file_two.pid]) 
    end
  end
end