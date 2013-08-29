require 'spec_helper' 

describe GenericFilesController do 
  let(:bill) { FactoryGirl.create(:bill) } 
  let(:bo) { FactoryGirl.create(:bo) } 

  describe "GET #new" do 

    it "goes to the upload page for users with no incomplete files" do 
      sign_in bo

      get :new, {:use_route => "Sufia::Engine" } 

      expect(response).to render_template("generic_files/new")  
    end
  end
end