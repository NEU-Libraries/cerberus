require 'spec_helper'

feature "Special content:" do
  before(:all) do
    ResqueSpec.inline = true
    # Set up an employee who has contributed one of everything
    # All contributions public except for his presentation.
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

        # private presentation
        if type == "Presentations"
          file.mass_permissions = "private"
        end

        file.save!

        instance_variable_set("@#{name}", file)
      end
    end

    # Set up a different employee who has contributed one presentation
    @lesser_contrib = FactoryGirl.create(:sequenced_employee)
    EmployeeCreateJob.new(@lesser_contrib.nuid, @lesser_contrib.name).run

    p = @lesser_contrib.smart_collections.find do |f|
      f.smart_collection_type = "Presentations"
    end

    @presentation2 = FactoryGirl.create(:docx_file).core_record
    @presentation2.category  = p.smart_collection_type
    @presentation2.title     = "Public Presentation"
    @presentation2.depositor = @lesser_contrib.nuid
    @presentation2.parent    = p
    @presentation2.save!
  end

  scenario "viewing research publications" do
    visit root_path

    # Verify research publications link exists
    expect(page).to have_content "Research Publications"
    find("a", :text => "Research Publications").click

    # Verify that clicking it leads to the expected place
    expect(current_path).to eq "/catalog"

    # Verify that a single item shows up
    research = page.all("article.drs-item")
    expect(research.length).to eq 1
    research.first.find("h4 a").click
    expect(current_path).to eq core_file_path(@research_publication.pid)
  end

  scenario "viewing presentations" do
    visit root_path

    expect(page).to have_content "Presentations"
    find("a", :text => "Presentations").click

    # Verify that clicking it leads to the expected place
    expect(current_path).to eq "/catalog"

    # Verify that a single item shows up
    presentations = page.all("article.drs-item")
    expect(presentations.length).to eq 1

    # Verify that that single item is /not/ the private presentation
    # that our more prolific employee created.
    presentations.first.find("h4 a").click
    expect(current_path).to eq core_file_path(@presentation2.pid)
  end

  after(:all) do
    @contributor.destroy
    @lesser_contrib.destroy
  end
end
