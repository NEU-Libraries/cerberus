require 'spec_helper' 

feature "Editing collections" do 
  before :all do 
    @root = Community.create(pid: "neu:1")
    @root.identifier = "neu:1"
    @root.rightsMetadata.permissions({person: '000000001'}, 'edit') 
    @root.mass_permissions = 'public'
    @root.title = "Root Collection"
    @root.save!
    @user = FactoryGirl.create(:bill)
    @collection = FactoryGirl.create(:valid_owned_by_bill)
  end

  # Assign reused lookup code to clean up test appearance a bit. 
  let(:perms) { page.all('div.permission') }
  let(:first_perm) { page.all('div.permission').first }    

  Capybara.save_and_open_page_path = 'tmp/test_out'

  scenario "Collection data preloads correctly in edit screen" do 
    features_sign_in @user 

    save_page

    visit edit_nu_collection_path(@collection)

    save_page

    #Verify data prefills correctly
    find_field('Title').value.should == 'Bills Collection'
    find_field('Description').value.should == 'Bills new collection' 


    find_field('Choose Mass Permissions:').value.should == 'public'   

    # Verify billsfriend@example.com is the only perm loaded for potential edits
    perms.length.should == 1 

    # Verify billsfriend@example.com's permission data loaded correctly 
    first_perm.all('select').first.value.should == 'person' 
    first_perm.find_field('Enter NUID or group name').value.should == '000000009' 
    first_perm.all('select').last.value.should == 'read' 

  end

  # Objects instantiated in before :all hooks aren't cleaned up by rails transactional behavior.
  # Fedora objects are generally not rolled back either. 
  after :all do 
    NuCollection.find(:all).each do |coll| 
      coll.destroy 
    end
    User.all.each do |user| 
      user.destroy 
    end 
  end
end 