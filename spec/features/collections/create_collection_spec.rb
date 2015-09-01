require 'spec_helper'

feature "Creating a collection" do

  before :all do
    User.all.each do |user|
      user.destroy
    end

    Employee.destroy_all

    @root = Community.create(pid: "neu:1")
    @root.identifier = "neu:1"
    @root.rightsMetadata.permissions({person: '000000001'}, 'edit')
    @root.mass_permissions = 'public'
    @root.title = "Root Collection"
    @root.save!
  end

  let(:employee)   { FactoryGirl.create(:employee) }
  let(:user) { FactoryGirl.create(:user) }
  let(:bill) { FactoryGirl.create(:bill) }

  describe "Unsigned Access Protection" do

    it "Redirects unsigned users to the signin page" do
      visit new_collection_path
      current_path.should == '/users/sign_in'
    end
  end

  describe "Signed Access and Form Creation" do
    scenario "Authenticated Creation and Edit" do
      features_sign_in bill
      visit new_collection_path(parent: @root.pid)

      # Because we authenticated we don't get booted out.
      current_path.should == '/collections/new'

      # Verifies that hidden 'parent' parameter is set correctly
      page.all('input#collection_parent').length.should == 1
      page.all('input#collection_parent').first.value.should == @root.pid

      # Fill out and submit the Collection creation form.
      fill_in 'Title', with: "My Title"
      fill_in 'Description', with: "My new collection"
      select 'public', from: "Choose Mass Permissions:"
      # fill_in "Enter NUID or group name", with: "Person Edit"
      # leaving this blank for now, "bill" doesn't have a group to choose I don't think
      select 'edit', from: "Should this identity be allowed to read or edit?"
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
    Collection.find(:all).each do |coll|
      coll.destroy
    end
  end
end
