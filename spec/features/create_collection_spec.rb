require 'spec_helper' 

feature "Creating a collection" do
  before :all do 
    @root = FactoryGirl.create(:root_collection) 
  end

  let(:user) { FactoryGirl.create(:user) }
   

  describe "Unsigned Access Protection" do 

    it "Redirects unsigned users to the signin page" do 
      visit new_nu_collection_path 
      current_path.should == '/users/sign_in'  
    end
  end

  describe "Signed Access and Form Creation" do
    scenario "Authenticated Creation and Edit" do
      sign_in user 
      visit new_nu_collection_path(parent: @root.identifier)

      # Because we authenticated we don't get booted out. 
      current_path.should == '/nu_collections/new'

      # Verifies that hidden 'parent' parameter is set correctly
      page.all('input#nu_collection_parent').length.should == 1 
      page.all('input#nu_collection_parent').first.value.should == @root.identifier

      # Fill out and submit the Collection creation form. 
      fill_in 'Title:', with: "My Title" 
      fill_in 'Description:', with: "My new collection" 
      fill_in 'Date of Issuance', with: Date.tomorrow.to_s
      fill_in "Creator's first name:", with: 'Will' 
      fill_in "Creator's last name:", with: 'Jackson' 
      fill_in "Enter an organization name:", with: "NU LTS" 
      fill_in "Add some relevant keywords", with: "Keyword One" 
      select 'registered', from: "Choose Mass Permissions:" 
      select 'person', from: "Are you trying to add a person or a group?" 
      fill_in "Enter NUID or group name", with: "Person Edit" 
      select 'edit', from: "Should this identity be allowed to read or edit?" 
      fill_in "Embargo Date:", with: Date.tomorrow.to_s 
      click_button 'Create Nu collection'  

      # Verify we've hit the right url. 
      current_path.include?('/nu_collections/neu:').should be true

      # Verify page is displaying the collection description 
      page.should have_content('My new collection')

      # Verify page has a properly formed breadcrumb 
      page.should have_selector(:css, 'ul.breadcrumb')
      page.should have_link('Root Collection')
      page.should have_selector('li.active')
      page.find('li.active').text.should == "My Title"
    end
  end

  after :all do 
    NuCollection.find(:all).each do |coll| 
      coll.destroy 
    end  
  end
end