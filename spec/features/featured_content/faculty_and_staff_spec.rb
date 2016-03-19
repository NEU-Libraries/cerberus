require 'spec_helper'

feature "Faculty and staff featured content" do
  before :all do
    ResqueSpec.inline = true
    @list = FactoryGirl.create_list(:sequenced_employee, 4)
    @list.map { |emp| EmployeeCreateJob.new(emp.nuid, emp.name).run }
    @employee_1 = @list.first
    @employee_2 = @list[1]
    @employee_3 = @list[2]
    @employee_4 = @list[3]
  end

  scenario "Visit featured content page and then employee page" do

    visit root_path

    # Verify employee state is as we expect it to be
    @list.map { |e| expect(e.is_building?).to be false }
    @list.map { |e| expect(e.smart_collections.length).to eq 8 }
    @list.map { |e| expect(e.mass_permissions).to eq "public" }

    # Ensure the "Faculty" featured content widget
    # has loaded
    expected_title = "[title='Browse faculty by name']"
    expect(page).to have_content("Faculty")
    expect(page).to have_css("div.featured-content a#{expected_title}")

    # Click the faculty link and verify we land on the right
    # page

    find("div.featured-content a#{expected_title}").click

    # TODO: This section is outdated, and needs to be fixed

    # expected_query = "f[active_fedora_model_ssi][]=Employee"
    # expect(current_path).to eq "/faculty_and_staff"
    # expect(URI.parse(current_url).query).to eq expected_query

    # Verify page header information is mostly correct
    # expect(page).to have_content("Search Results")
    # expect(page).to have_css("span.filterValue")
    # expect(page.find("span.filterValue").text).to eq "Employee"

    # Verify we're being shown four employees and that the information
    # for each of the employees is correct
    expect(page).to have_css("ul.drs-items.drs-items-list")
    employees = page.all("article.drs-item")
    expect(employees.length).to eq 4

    # TODO: Names section needs updating, no longer works.

    # names = @list.map { |employee| employee.name }
    # employees.each do |employee|
    #   caption = employee.find("figcaption span").text
    #   displayed_name = employee.find("h4.drs-item-title a").text

    #   expect(caption).to eq "Person"
    #   expect(displayed_name.present?).to be true
    #   expect(names).to include displayed_name

    #   # Delete name from array to ensure that test breaks if
    #   # the same name is being rendered multiple times by the page
    #   names.delete(displayed_name)
    # end

    # Verify pagination div did not load - once we have tests where
    # enough fixture objects exist we can check for its existence which is
    # probably more interesting + important.
    expect(page).not_to have_content "div.pager"

    # Verify facets/display mode/sorting sidebar controls exist and are
    # working
    expect(page).to have_css "aside.drs-sidebar"
    expect(page).to have_css "div.pagination-info.pane"
    expect(page).to have_css "div.pagination-info.pane select[name='sort']"

    # Sorting currently does nothing to Employees, so once that works
    # determine what sort order of employees will be and add tests for
    # sorting employees

    # Verify clicking an employee brings you to the show action for that
    # employee.  Do not verify things about the functioning of the employee#show
    # action.  Best in a separate test
    expected_path = employee_path(@employee_1.pid)
    find("h4.drs-item-title a[href='#{expected_path}']").click
    expect(current_path).to eq expected_path
  end

  after(:all) do
    ResqueSpec.inline = false
    @list.map { |employee| employee.destroy }
  end
end
