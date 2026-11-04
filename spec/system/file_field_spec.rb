# frozen_string_literal: true

require 'rails_helper'

# shared/_file_field hides the native file button under its own, so what only a
# browser can show is here: that choosing a file names it, and that the
# transparent input still stops an empty submit. The Upload File page stands in
# for every page that renders the partial.
RSpec.describe 'File field', :browser, type: :system do
  before(:all) do
    Current.nuid = AtlasFixtures::ADMIN_NUID
    @work = create_work(create_collection(create_community(public: true).id, public: true).id, public: true)
  end

  before do
    sign_in_as(admin_nuid)
    visit "/works/#{@work.id}/upload"
  end

  it 'reads Choose file, and names the file once one is chosen' do
    expect(page).to have_css('.file-field__button', text: 'Choose file')
    expect(page).to have_css('.file-field__name', text: 'No file chosen')

    find_by_id('binary', visible: :all).set(Rails.root.join('spec/fixtures/files/image.png').to_s)

    expect(page).to have_css('.file-field--chosen .file-field__name', text: 'image.png')
  end

  it 'still refuses an empty submit, on the required input' do
    click_button 'Upload'

    expect(page).to have_current_path("/works/#{@work.id}/upload")
    expect(page.evaluate_script("document.getElementById('binary').validity.valueMissing")).to be(true)
  end
end
