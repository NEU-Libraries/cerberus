require 'spec_helper' 

feature "Uploading a single file" do 
  let(:user) { FactoryGirl.create(:user) }

  before { sign_in user }
  before { visit '/' } 

  it "Upload page is accessible from home page" do 
    page.should have_link("contribute_link")  
  end

  describe "Navigating to file upload" do 
    before :all do
      visit '/'
      page.click_link('contribute_link') 
    end 

    it "Has a properly formed upload screen" do
      expect(page).to have_content "Upload"  
    end
  end

  #TODO: Finish post page refactor
end 