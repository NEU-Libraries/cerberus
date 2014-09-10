require 'spec_helper'

feature "Special content:" do
  before(:all) do
    ResqueSpec.inline = true
    # Set up an employee who has contributed one of everything
    # All contributions public except for his presentation.
    puts "running setup"
    @contributor = FactoryGirl.create(:sequenced_employee)
    EmployeeCreateJob.new(@contributor.nuid, @contributor.name).run

    @contributor.smart_collections.each do |collection|
      type = collection.smart_collection_type

      unless type == "User Root"
        file                  = FactoryGirl.create(:pdf_file).core_record
        file.depositor        = @contributor.nuid
        file.parent           = collection
        file.mass_permissions = "public"
        file.category         = type
        file.title            = "Sample #{type}"

        name = type.singularize.underscore.sub(" ", "_")

        file.save!

        instance_variable_set("@#{name}", file)
      end
    end
  end

  shared_examples_for "a special content page" do |category_name|
    scenario "visiting page" do
      content_name = category_name.singularize.underscore.sub(" ", "_")
      content_item = instance_variable_get("@#{content_name}")

      visit root_path

      expect(page).to have_content category_name
      find("a.btn-block", :text => category_name).click

      # Verify that clicking it leads to the expected place
      expect(current_path).to eq "/catalog"

      # Verify that the query string is as expected
      query = URI.parse(current_url).query
      expected_query = "f[drs_category_ssim][]=#{category_name.sub(' ', '+')}"
      expect(query).to eq expected_query

      # Verify that a single item shows up
      items = page.all("article.drs-item")
      expect(items.length).to eq 1

      # Verify that the item created, when clicked, leads to where we'd expect
      items.first.find("h4 a").click
      expect(current_path).to eq core_file_path(content_item.pid)
    end
  end

  it_should_behave_like "a special content page", "Research Publications"
  it_should_behave_like "a special content page", "Presentations"
  it_should_behave_like "a special content page", "Learning Objects"
  it_should_behave_like "a special content page", "Datasets"

  after(:all) { @contributor.destroy }
end
