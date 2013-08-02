require 'spec_helper' 

feature "Uploading a single file" do 
  let(:user) { FactoryGirl.create(:user) }

  before { sign_in user }
  before { visit '/' } 

  it "Upload page is accessible from home page" do 
    page.should have_link("contribute_link")  
  end

  describe "Navigating to file upload" do 
    before do
      visit '/'
      page.click_link('contribute_link') 
    end 

    it "Has a properly formed upload screen" do
      expect(page).to have_content "Upload"
      expect(page).to have_css('form#fileupload')
      expect(page).to have_selector('span', text: "Select files...")
      expect(page).to have_selector('span', text: "Start upload")
      expect(page).to have_selector('input', 'files[]')
    end

    it "Can upload a file" do 
      attach_file "files[]", "#{Rails.root}/spec/fixtures/test_pic.jpeg"
      #TODO: Verify this actually does something.
    end
  end

  #TODO: Finish post page refactor
end 