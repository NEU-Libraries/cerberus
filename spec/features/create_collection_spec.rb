require 'spec_helper' 

feature "Creating a collection" do
  before :all do 
    @root = Community.create(pid: "neu:1")
    @root.identifier = "neu:1"
    @root.rightsMetadata.permissions({person: 'bill@example.com'}, 'edit') 
    @root.mass_permissions = 'public'
    @root.title = "Root Collection"
    @root.save!
  end

  let(:user) { FactoryGirl.create(:user) }
  let(:bill) { FactoryGirl.create(:bill) } 
   

  describe "Unsigned Access Protection" do 

    it "Redirects unsigned users to the signin page" do 
      visit new_nu_collection_path 
      current_path.should == '/users/sign_in'  
    end
  end

  describe "Signed Access and Form Creation" do
    scenario "Authenticated Creation and Edit" do
      features_sign_in bill
      visit new_nu_collection_path(parent: @root.identifier)

      # Because we authenticated we don't get booted out. 
      current_path.should == '/collections/new'

      # Verifies that hidden 'parent' parameter is set correctly
      page.all('input#nu_collection_parent').length.should == 1 
      page.all('input#nu_collection_parent').first.value.should == @root.identifier

      # Fill out and submit the Collection creation form. 
      fill_in 'Title *', with: "My Title" 
      fill_in 'Description *', with: "My new collection" 
      fill_in 'Date of Issuance *', with: Date.tomorrow.to_s
      fill_in "Creator's first name", with: 'Will' 
      fill_in "Creator's last name", with: 'Jackson' 
      fill_in "Organziation", with: "NU LTS" 
      fill_in "Keyword", with: "Keyword One" 
      select 'public', from: "Choose Mass Permissions:" 
      select 'person', from: "Are you trying to add a person or a group?" 
      fill_in "Enter NUID or group name", with: "Person Edit" 
      select 'edit', from: "Should this identity be allowed to read or edit?" 
      fill_in "Embargo Date:", with: Date.tomorrow.to_s 
      click_button 'Submit'  

      # Verify we've hit the right url. 
      current_path.include?('/collections/neu:').should be true

      # Verify page is displaying the collection description 
      page.should have_content('My new collection')

      # Verify page has a properly formed breadcrumb 
      page.should have_selector(:css, 'ul.breadcrumb')
      page.should have_link('Root Collection')
      page.should have_selector('li.active')
      page.find('ul.breadcrumb > li.active').text.should == "My Title"
    end
  end

  after :all do 
    NuCollection.find(:all).each do |coll| 
      coll.destroy 
    end  
  end
end