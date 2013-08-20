require 'spec_helper' 

feature "Creating a collection" do 
  let(:user) { FactoryGirl.create(:user) }
   

  describe "Unsigned Access Protection" do 

    it "Redirects unsigned users to the signin page" do 
      visit new_nu_collection_path 
      current_path.should == '/users/sign_in'  
    end
  end

  describe "Signed Access and Form Creation" do
    let(:root){ FactoryGirl.create(:root_collection) } 

    before :all do 
      @root = FactoryGirl.create(:root_collection) 
      @root_pid = @root.pid 
    end

    scenario "Authenticated Creation and Edit" do
      sign_in user 
      visit new_nu_collection_path(parent: @root_pid)

      # Because we authenticated we don't get booted out. 
      current_path.should == '/nu_collections/new'

      # Verifies that hidden 'parent' parameter is set correctly
      page.all('input#nu_collection_parent').length.should == 1 
      page.all('input#nu_collection_parent').first.value.should == @root_pid 

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

    after :all do 
      root.destroy  
    end
  end
end

# describe "Object correctness in Fedora" do 
#   let(:new_item) { NuCollection.find(new_item_pid) }

#   it "Has a parent" do 
#     new_item.parent.should == root 
#   end

#   it "Has valid identifier set" do
#     new_item.identifier.should == new_item_pid 
#   end 

#   it "Has a title" do 
#     new_item.title.should == "My Title" 
#   end

#   it "Has a description" do 
#     new_item.description.should == "My new collection" 
#   end

#   it "Has a date of issuance" do 
#     new_item.date_of_issue.should == Date.tomorrow.to_s 
#   end

#   it "Has a single personal creator" do 
#     new_item.personal_creators.should == [{first: 'Will', last: 'Jackson'}] 
#   end

#   it "Has a single corporate creator" do 
#     new_item.corporate_creators.should == ['NU LTS'] 
#   end

#   it "Has a single keyword" do 
#     new_item.keywords.should == ['Keyword One'] 
#   end

#   it "Has mass permissions set to 'registered'" do 
#     new_item.mass_permissions.should == 'registered' 
#   end

#   it "Has correctly set permissions" do
#     registered = { type: 'group', access: 'read', name: 'registered' }
#     edit_guy = { type: 'user', access: 'edit', name: 'Person Edit' }
#     depositor_edit = { type: 'user', access: 'edit', name: user.email }  
#     all_perms = new_item.permissions

#     all_perms.length.should == 3
#     all_perms.include?(registered).should be true 
#     all_perms.include?(edit_guy).should be true
#     all_perms.include?(depositor_edit).should be true 
#   end

#   it "Has a properly set embargo date" do 
#     new_item.embargo_release_date.should == Date.tomorrow.to_s 
#   end
# end