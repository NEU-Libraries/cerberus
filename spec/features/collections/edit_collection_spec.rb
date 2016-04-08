require 'spec_helper'

feature "Editing collections" do
  before :all do
    Employee.destroy_all
    @root = Community.create(pid: "neu:1")
    @root.identifier = "neu:1"
    @root.rightsMetadata.permissions({person: '000000001'}, 'edit')
    @root.mass_permissions = 'public'
    @root.title = "Root Collection"
    @root.save!
    @user = FactoryGirl.create(:bill)
    @collection = FactoryGirl.create(:valid_owned_by_bill)
    EmployeeCreateJob.new(@user.nuid, "John Doe").run
    @emp = Employee.find_by_nuid(@user.nuid)
    @admin = FactoryGirl.create(:admin)
    @admin.add_group("northeastern:drs:repository:staff")
    @admin.save!
    @user_collection = Collection.create(title: "User Collection", parent: @emp.user_root_collection, depositor:@user.nuid)
    @user_collection.smart_collection_type == "miscellany"
    @user_collection.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")
    @user_collection.save!
  end

  # Assign reused lookup code to clean up test appearance a bit.
  let(:perms) { page.all('div.permission') }
  let(:first_perm) { page.all('div.permission').first }

  Capybara.save_and_open_page_path = 'tmp/test_out'

  scenario "Collection data preloads correctly in edit screen" do
    features_sign_in @user

    save_page

    visit collection_path(@collection.pid)
    page.all("a[href='/collections/#{@collection.pid}/edit']").length.should == 1
    find("a[href='/collections/#{@collection.pid}/edit']").click
    save_page

    #Verify data prefills correctly
    find_field('Title').value.should == 'Bills Collection'
    find_field('Description').value.should == 'Bills new collection'


    find_field('Choose Mass Permissions:').value.should == 'public'

    # Verify billsfriend@example.com is the only perm loaded for potential edits
    perms.length.should == 1

    # TODO - refactor this spec. We no longer do person permissions on the form, only groups
    # Verify billsfriend@example.com's permission data loaded correctly
    # first_perm.all('select').first.value.should == 'person'
    # first_perm.find_field('Enter NUID or group name').value.should == '000000009'
    # first_perm.all('select').last.value.should == 'read'

    #user can see all four tabs- edit, move, delete, statistics # is_smart_collection? == false
    @collection.is_smart_collection?.should == false
    page.all('a[href="#edit"]').length.should == 1
    page.all('a[href="#move"]').length.should == 1
    page.all('a[href="#delete"]').length.should == 1
    page.all('a[href="#statistics"]').length.should == 1
  end

  scenario "user edits own smart collection" do
    # is_smart_collection? == true
    # smart_collection_type != "miscellany"
    # user can see statistics and special message about not editing, no move or delete
    features_sign_in @user

    smart_col = @emp.smart_collections.last
    visit collection_path(smart_col.pid)
    page.all("a[href='/collections/#{smart_col.pid}/edit']").length.should == 1
    find("a[href='/collections/#{smart_col.pid}/edit']").click
    smart_col.is_smart_collection?.should == true
    smart_col.smart_collection_type.should_not == "miscellany"
    page.all('a[href="#edit"]').length.should == 1
    page.all('a[href="#move"]').length.should == 0
    page.all('a[href="#delete"]').length.should == 0
    page.all('a[href="#statistics"]').length.should == 1
    page.should have_content("This Smart Collection is designed to help you easily share your scholarly work with the Northeastern University community. The files you upload to this collection will be displayed as part of your communities' collections, as well.") #taken from en.yml drs.personal_graphy.full_description
  end

  scenario "user edits own personal collection" do
    # is_smart_collection? == true
    # smart_collection_type == "miscellany"
    # user can see edit, move, delete, statistics
    features_sign_in @user
    visit collection_path(@user_collection.pid)
    @user_collection.is_smart_collection? == true
    page.all("a[href='/collections/#{@user_collection.pid}/edit']").length.should == 1
    find("a[href='/collections/#{@user_collection.pid}/edit']").click
    page.all('a[href="#edit"]').length.should == 1
    page.all('a[href="#move"]').length.should == 1
    page.all('a[href="#delete"]').length.should == 1
    page.all('a[href="#statistics"]').length.should == 1
  end

  scenario "admin user can see edit collection button for all collections" do
    features_sign_in @admin
    visit collection_path(@user_collection.pid)
    page.all("a[href='/collections/#{@user_collection.pid}/edit']").length.should == 1
    smart_col = @emp.smart_collections.last
    visit collection_path(smart_col.pid)
    page.all("a[href='/collections/#{smart_col.pid}/edit']").length.should == 1
    visit collection_path(@collection.pid)
    page.all("a[href='/collections/#{@collection.pid}/edit']").length.should == 1
  end

  # Objects instantiated in before :all hooks aren't cleaned up by rails transactional behavior.
  # Fedora objects are generally not rolled back either.
  after :all do
    ActiveFedora::Base.destroy_all
    User.destroy_all
  end
end
