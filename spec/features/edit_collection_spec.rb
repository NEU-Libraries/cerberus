require 'spec_helper' 

feature "Editing collections" do 
  before :all do 
    @root = FactoryGirl.create(:root_collection)
    @collection = FactoryGirl.create(:valid_owned_by_bill)
    @user = FactoryGirl.create(:bill) 
  end

  # Assign reused lookup code to clean up test appearance a bit. 
  let(:creator_firsts) { page.all('input#nu_collection_creator_first_name') } 
  let(:creator_lasts) { page.all('input#nu_collection_creator_last_name') } 
  let(:corporate_creators) { page.all('input#nu_collection_corporate_creators') }
  let(:keywords) { page.all('input#nu_collection_keywords') }
  let(:perms) { page.all('div.permission') }
  let(:first_perm) { page.all('div.permission').first }    

  scenario "Collection data preloads correctly in edit screen" do 
    features_sign_in @user 

    visit edit_nu_collection_path(@collection)

    #Verify data prefills correctly
    find_field('Title *').value.should == 'Bills Collection'
    find_field('Description *').value.should == 'Bills new collection' 
    find_field('Date of Issuance').value.should == Date.yesterday.to_s 

    # Personal creator names 
    creator_firsts.at(0).value.should == "David" 
    creator_firsts.at(1).value.should == "Steven" 
    creator_firsts.at(2).value.should == "Will" 
    creator_lasts.at(0).value.should == "Cliff"
    creator_lasts.at(1).value.should == "Bassett" 
    creator_lasts.at(2).value.should == "Jackson" 

    # Corporate creator names
    corporate_creators.at(0).value.should == "Corp One" 
    corporate_creators.at(1).value.should == "Corp Two" 
    corporate_creators.at(2).value.should == "Corp Three"

    # Keywords 
    keywords.at(0).value.should == "kw one"  
    keywords.at(1).value.should == "kw two" 
    keywords.at(2).value.should == "kw three" 

    find_field('Choose Mass Permissions:').value.should == 'public'   

    # Verify billsfriend@example.com is the only perm loaded for potential edits
    perms.length.should == 1 

    # Verify billsfriend@example.com's permission data loaded correctly 
    first_perm.all('select').first.value.should == 'person' 
    first_perm.find_field('Enter NUID or group name').value.should == 'billsfriend@example.com' 
    first_perm.all('select').last.value.should == 'read' 

    find_field('Embargo Date:').value.should == Date.yesterday.to_s 
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