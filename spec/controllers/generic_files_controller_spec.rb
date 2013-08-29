require 'spec_helper' 

describe GenericFilesController do 
  let(:bill) { FactoryGirl.create(:bill) } 
  let(:bo) { FactoryGirl.create(:bo) } 

  describe "GET #new" do 

    # Ensures no contamination between test runs. 
    after(:each) do 
      a = GenericFile.find(:all).each do |file| 
        file.destroy 
      end
    end

    it "goes to the upload page for users with no incomplete files" do 
      sign_in bo

      get :new, {:use_route => "Sufia::Engine" } 

      expect(response).to render_template("generic_files/new")  
    end

    it "goes to the rescue incomplete files page for users with incomplete files" do 
      sign_in bill 

      a = FactoryGirl.create(:bills_incomplete_file) 

      get :new, {:use_route => "Sufia::Engine" } 

      expect(response).to redirect_to(rescue_incomplete_files_path(file0: a.pid))  
    end
  end

  describe "DELETE #destroy_incomplete_files" do 

    # Ensures no contamination between test runs. 
    after(:each) do 
      a = GenericFile.find(:all).each do |file| 
        file.destroy 
      end
    end

    it "removes every incomplete file associated with the signed in user" do 
      sign_in bill 

      incomplete_files = FactoryGirl.create_list(:bills_incomplete_file, 3)
      complete_file = FactoryGirl.create(:bills_complete_file)

      delete :destroy_incomplete_files 

      # Check that the files just created were deleted
      bills_incomplete_files = GenericFile.users_in_progress_files(bill) 
      bills_incomplete_files.length.should == 0 

      # Check that bills complete file was not deleted 
      GenericFile.find(complete_file.pid).should == complete_file 


      expect(response).to redirect_to(files_provide_metadata_path) 
    end 
  end

  describe "Get #provide_metadata" do 

    # Ensures no contamination between test runs 
    after(:each) do 
      a = GenericFile.find(:all).each do |file| 
        file.destroy 
      end
    end

    it "loads all of the users current incomplete files" do 
      sign_in bill 

      file_one = FactoryGirl.create(:bills_incomplete_file) 
      file_two = FactoryGirl.create(:bills_incomplete_file)
      complete_file = FactoryGirl.create(:bills_complete_file) 

      get :provide_metadata 

      assigns(:incomplete_files).should =~ [file_one, file_two] 

      expect(response).to render_template('generic_files/provide_metadata') 
    end
  end
end