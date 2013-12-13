require 'spec_helper' 

describe NuCoreFilesController do 
  let(:bill) { FactoryGirl.create(:bill) } 
  let(:bo)   { FactoryGirl.create(:bo) }
  let(:root) { FactoryGirl.create(:root_collection) }

  let(:file) { FactoryGirl.create(:complete_file, 
                                  depositor: "000000001", 
                                  parent: root) }

  describe "GET #new" do 

    # Ensures no contamination between test runs. 
    after(:each) do 
      a = NuCoreFile.find(:all).each do |file| 
        file.destroy 
      end
    end

    it "goes to the upload page for users with no incomplete files and edit permissions on the assigned parent" do 
      sign_in bill

      get :new, { parent: root.identifier } 

      expect(response).to render_template('nu_core_files/new')   
    end

    it "goes to the rescue incomplete files page for users with incomplete files" do 
      sign_in bill 

      a = FactoryGirl.create(:bills_incomplete_file) 

      get :new, { parent: root.identifier } 

      expect(response).to redirect_to(rescue_incomplete_files_path(file0: a.pid))  
    end

    it "403s if authed user has no edit permissions on the parent object" do 
      sign_in bo 

      get :new, { parent: root.identifier } 

      response.status.should == 403 
    end

    it "redirects to the home page if no parent is set" do 
      sign_in bill 

      get :new 

      expect(response).to redirect_to(root_path) 
    end

    it "redirects to the home page if a bogus parent is set" do 
      sign_in bill 

      get :new, { parent: "neu:assuredlyIDoNotExist" } 

      expect(response).to redirect_to(root_path) 
    end
  end

  describe "GET #show" do 

    it "renders the 404 page for objects that do not exist" do 
      get :show, { id: 'neu:adsfasdfa' } 
      expect(response).to render_template('error/object_404') 
    end
  end

  describe "DELETE #destroy" do  
    it "requests authentication for unauthed users" do 
      delete :destroy, { id: file.pid } 
      expect(response).to redirect_to(new_user_session_path) 
    end

    it "403s for users without edit permissions" do 
      file.mass_permissions = 'public' && file.save! 
      file_pid = file.pid

      sign_in bo 

      delete :destroy, { id: file.pid }
      NuCoreFile.exists?(file_pid).should be true 
      response.status.should == 403 
    end

    it "successfully removes the item for users with edit permissions" do 
      sign_in bill 
      file_pid = file.pid

      delete :destroy, { id: file.pid }
      expect(response).to be_redirect 
      NuCoreFile.exists?(file_pid).should be false
    end
  end

  describe "DELETE #destroy_incomplete_files" do 

    # Ensures no contamination between test runs. 
    after(:each) do 
      a = NuCoreFile.find(:all).each do |file| 
        file.destroy 
      end
    end

    it "removes every incomplete file associated with the signed in user" do 
      sign_in bill 

      incomplete_files = FactoryGirl.create_list(:bills_incomplete_file, 3)
      complete_file = FactoryGirl.create(:bills_complete_file)

      delete :destroy_incomplete_files 

      # Check that the files just created were deleted
      bills_incomplete_files = NuCoreFile.users_in_progress_files(bill) 
      bills_incomplete_files.length.should == 0 

      # Check that bills complete file was not deleted 
      NuCoreFile.find(complete_file.pid).should == complete_file 


      expect(response).to redirect_to(new_nu_core_file_path) 
    end 
  end

  describe "GET #provide_metadata" do 

    # Ensures no contamination between test runs 
    after(:each) do 
      a = NuCoreFile.find(:all).each do |file| 
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

      expect(response).to render_template('nu_core_files/provide_metadata') 
    end
  end
end