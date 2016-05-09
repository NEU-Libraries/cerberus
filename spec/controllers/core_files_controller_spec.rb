require 'spec_helper'

describe CoreFilesController do
  let(:bill) { FactoryGirl.create(:bill) }
  let(:bo)   { FactoryGirl.create(:bo) }
  let(:admin) { FactoryGirl.create(:admin) }
  let(:root) { FactoryGirl.create(:root_collection) }

  let(:file) { FactoryGirl.create(:complete_file,
                                  depositor: "000000001",
                                  parent: root) }

  after(:all) do
    ActiveFedora::Base.destroy_all
    User.destroy_all
  end

  describe "GET #new" do

    # Ensures no contamination between test runs.
    after(:each) do
      a = CoreFile.find(:all).each do |file|
        file.destroy
      end
    end

    it "goes to the upload page for users with no incomplete files and edit permissions on the assigned parent" do
      sign_in bill

      get :new, { parent: root.pid }

      expect(response).to render_template('core_files/new')
    end

    it "goes to the rescue incomplete files page for users with incomplete files" do
      sign_in bill

      a = FactoryGirl.create(:bills_incomplete_file)

      Timecop.travel(7.hours) do
        get :new, { parent: root.pid }
        expect(response).to redirect_to(rescue_incomplete_file_path(abandoned: a.pid))
      end
    end

    it "403s if authed user has no edit permissions on the parent object" do
      sign_in bo

      get :new, { parent: root.pid }

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
      expect(response).to render_template('error/404')

      ImpressionProcessingJob.new().run
      Impression.count.should == 0
    end

    it "renders the 410 page for objects that have been tombstoned" do
      file.tombstone
      get :show, { id: file.pid }
      expect(response).to render_template('error/410')
    end

    it "renders the show page for valid, authenticated requests" do
      sign_in bill

      get :show, { id: file.pid }
      expect(response).to render_template('core_files/show')

      ImpressionProcessingJob.new().run
      Impression.count.should == 1
      doc = SolrDocument.new(file.to_solr)
      doc.impression_views.should == 1
    end

    it "only writes a single impression on multiple hits" do
      sign_in bill

      get :show, { id: file.pid }
      get :show, { id: file.pid }

      ImpressionProcessingJob.new().run
      Impression.count.should == 1
      doc = SolrDocument.new(file.to_solr)
      doc.impression_views.should == 1
    end
  end

  describe "DELETE #destroy_incomplete_files" do

    # Ensures no contamination between test runs.
    after(:each) do
      a = CoreFile.find(:all).each do |file|
        file.destroy
      end
    end

    it "removes an incomplete file associated with the signed in user" do
      sign_in bill

      incomplete_files = FactoryGirl.create_list(:bills_incomplete_file, 3)
      complete_file = FactoryGirl.create(:bills_complete_file)

      Timecop.travel(7.hours) do
        delete :destroy_incomplete_file, id: incomplete_files.first.pid
      end

      # Check that the files just created were deleted
      # bills_incomplete_files = CoreFile.abandoned_for_nuid(bill.nuid)
      # bills_incomplete_files.length.should == 2

      # Check that bills complete file was not deleted
      CoreFile.find(complete_file.pid).should == complete_file

      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE #destroy_incomplete_content_object" do

    # Ensures no contamination between test runs.
    after(:each) do
      a = VideoMasterFile.find(:all).each do |file|
        file.destroy
      end
    end

    it "removes an incomplete file associated with the signed in user" do
      sign_in admin

      incomplete_co = VideoMasterFile.new()
      incomplete_co.properties.tag_as_incomplete
      incomplete_co.save!
      complete_co = VideoMasterFile.new()
      complete_co.save!

      Timecop.travel(7.hours) do
        delete :destroy_incomplete_content_object, id: incomplete_co.pid
        CoreFile.abandoned_for_nuid(bill.nuid).length.should == 0
      end

      # Check that bills complete content_object was not deleted
      VideoMasterFile.find(complete_co.pid).should == complete_co

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #provide_metadata" do

    # Ensures no contamination between test runs
    after(:each) do
      a = CoreFile.find(:all).each do |file|
        file.destroy
      end
    end

    # This can be brought down to just one, given we've moved away from batch upload at this point
    it "loads all of the users current incomplete files" do
      sign_in bill

      file_one = FactoryGirl.create(:bills_complete_file)

      get :provide_metadata, id: file_one.pid

      assigns(:core_file).should == file_one

      expect(response).to render_template('core_files/provide_metadata')
    end
  end

  describe "GET #provide_file_metadata" do
    before(:each) do
      file.canonical_class = "VideoFile"
      file.save!
      sign_in admin
      emp = EmployeeCreateJob.new(admin.nuid, "John Doe").run
      test_file = fixture_file_upload("/files/video.mp4")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      @video = VideoMasterFile.first
      sign_out admin
    end

    after(:each) do
      VideoMasterFile.destroy_all
    end

    it "should render provide_file_metadata template for admin users" do
      sign_in admin
      get :provide_file_metadata, id: file.pid, content_object_id:@video.pid
      expect(response).to render_template('core_files/provide_file_metadata')
    end

    it "should redirect to user signin non logged in users" do
      sign_out bill
      sign_out bo
      sign_out admin
      get :provide_file_metadata, id: file.pid, content_object_id:@video.pid
      expect(response).to redirect_to(new_user_session_path)
    end

    it "should 403 for non admin users" do
      sign_in bo
      get :provide_file_metadata, id: file.pid, content_object_id:@video.pid
      response.status.should == 403
    end

    it "should get core file object from params" do
      sign_in admin
      get :provide_file_metadata, id: file.pid, content_object_id:@video.pid
      assigns(:core_file).should == file
    end

    it "should have page title" do
      sign_in admin
      get :provide_file_metadata, id: file.pid, content_object_id:@video.pid
      assigns(:page_title).should == "Provide File Metadata"
    end

    it "assigns content_object" do
      sign_in admin
      get :provide_file_metadata, id: file.pid, content_object_id:@video.pid
      assigns(:content_object).should == @video
    end
  end

  describe "POST #process_file_metadata" do
      before(:each) do
        file.canonical_class = "VideoFile"
        file.save!
        emp = EmployeeCreateJob.new(admin.nuid, "John Doe").run
        sign_out bill
        sign_out bo
        sign_in admin
        test_file = fixture_file_upload("/files/video.mp4")
        post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
        @video = VideoMasterFile.first
        sign_out admin
      end

      after(:each) do
        VideoMasterFile.destroy_all
      end

      it "403s for users not admin" do
        sign_in bo
        content_object = {mass_permissions:"public", permissions:{"identity"=>["northeastern:drs:repository:staff"], "permission_type"=>["edit"]}}
        post :process_file_metadata, id:file.pid, content_object_id:@video.pid, content_object:content_object
        response.status.should == 403
      end

      it "redirects to user signin for non logged in users" do
        sign_out bill
        sign_out bo
        sign_out admin
        content_object = {mass_permissions:"public", permissions:{"identity"=>["northeastern:drs:repository:staff"], "permission_type"=>["edit"]}}
        post :process_file_metadata, id:file.pid, content_object_id:@video.pid, content_object:content_object
        expect(response).to redirect_to(new_user_session_path)
      end

      it "assigns core_file" do
        sign_in admin
        content_object = {mass_permissions:"public", permissions:{"identity"=>["northeastern:drs:repository:staff"], "permission_type"=>["edit"]}}
        post :process_file_metadata, id:file.pid, content_object_id:@video.pid, content_object:content_object
        assigns(:core_file) == file
      end

      it "assigns content_object" do
        sign_in admin
        content_object = {mass_permissions:"public", permissions:{"identity"=>["northeastern:drs:repository:staff"], "permission_type"=>["edit"]}}
        post :process_file_metadata, id:file.pid, content_object_id:@video.pid, content_object:content_object
        assigns(:content_object).should == @video
      end

      it "redirects to core_file_path" do
        sign_in admin
        content_object = {mass_permissions:"public", permissions:{"identity"=>["northeastern:drs:repository:staff"], "permission_type"=>["edit"]}}
        post :process_file_metadata, id:file.pid, content_object_id:@video.pid, content_object:content_object
        expect(response).to redirect_to core_file_path(file.pid)+"#no-back"
      end

      it "sets flash:notice" do
        sign_in admin
        content_object = {mass_permissions:"public", permissions:{"identity"=>["northeastern:drs:repository:staff"], "permission_type"=>["edit"]}}
        post :process_file_metadata, id:file.pid, content_object_id:@video.pid, content_object:content_object
        expect(flash[:notice]).to be_present
      end

      it "kicks job off to queue" do
        pending_before = Resque.info[:pending]
        sign_in admin
        content_object = {mass_permissions:"public", permissions:{"identity"=>["northeastern:drs:repository:staff"], "permission_type"=>["edit"]}}
        post :process_file_metadata, id:file.pid, content_object_id:@video.pid, content_object:content_object
        Resque.info[:pending].should == pending_before + 1
      end

      it "creates uploadAlert" do
        ua_before = UploadAlert.count
        sign_in admin
        content_object = {mass_permissions:"public", permissions:{"identity"=>["northeastern:drs:repository:staff"], "permission_type"=>["edit"]}}
        post :process_file_metadata, id:file.pid, content_object_id:@video.pid, content_object:content_object
        UploadAlert.count.should == ua_before + 1
      end
  end

  describe "POST #create_attached_file" do
    it "403s for users not admin" do
      sign_in bo
      test_file = fixture_file_upload("/files/image.png")
      post :create_attached_file, id:file.pid, file:test_file
      response.status.should == 403
    end

    it "redirects to user signin for non logged in users" do
      sign_out bill
      sign_out bo
      sign_out admin
      test_file = fixture_file_upload("/files/image.png")
      post :create_attached_file, id:file.pid, file:test_file
      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns json_error Error! No file to save if file is empty" do
      sign_in admin
      get :new_attached_file, id:file.pid
      post :create_attached_file, id:file.pid, file:nil, terms_of_service:1
      @expected = {:url=>"/files/#{file.pid}/new"}.to_json
      response.body.should == @expected
      session[:flash_error].should == "Error! No file for upload"
    end

    it "returns json_error Error! No file to save if params doesn't have file param" do
      sign_in admin
      get :new_attached_file, id:file.pid
      post :create_attached_file, id:file.pid
      @expected = [{:error=>"Error! No file to save"}].to_json
      response.body.should == @expected
    end

    it "returns json error for empty_file?" do
      sign_in admin
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/empty_file.mov") #has file_size 0
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      @expected = {:url=>"/files/#{file.pid}/new"}.to_json
      response.body.should == @expected
      session[:flash_error].should == "Error! Zero Length File!"
    end

    it "returns json error if !terms_accepted?" do
      sign_in admin
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/image.png")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:0 #terms_of_service param not checked
      @expected = {:url=>"/files/#{file.pid}/new"}.to_json
      response.body.should == @expected
      session[:flash_error].should == "You must accept the terms of service!"
      get :new_attached_file, id:file.pid
      post :create_attached_file, id:file.pid, file:test_file #no terms_of_service param
      @expected = {:url=>"/files/#{file.pid}/new"}.to_json
      response.body.should == @expected
      session[:flash_error].should == "You must accept the terms of service!"
    end

    it "returns proxy select error if user is proxy user and type of upload not selected" do
      admin.add_group("northeastern:drs:repository:proxystaff")
      admin.save!
      sign_in admin
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/image.png")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1, upload_type:nil
      session[:flash_error].should == "You must select whether this is a proxy or personal upload"
      @expected = {:url=>"/files/#{file.pid}/new"}.to_json
      response.body.should == @expected
      admin.delete_group("northeastern:drs:repository:proxystaff")
    end

    it "returns json error if type of uploaded file does not match canonical class - test only audio and video for now" do
      sign_in admin

      # canonical_class is nil
      file.canonical_class = nil
      file.save!
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/image.png")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      session[:flash_error].should  == "The type of file uploaded doesn't match the type of the existing file, which is a #{I18n.t("drs.display_labels.#{file.canonical_class}.short")}."
      @expected = {:url=>"/files/#{file.pid}/new"}.to_json
      response.body.should == @expected

      #canonical_class is "AudioFile"
      file.canonical_class = "AudioFile"
      file.save!
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/image.png")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      session[:flash_error].should  == "The type of file uploaded doesn't match the type of the existing file, which is a #{I18n.t("drs.display_labels.#{file.canonical_class}.short")}."
      @expected = {:url=>"/files/#{file.pid}/new"}.to_json
      response.body.should == @expected

      #canonical_class is "VideoFile"
      file.canonical_class = "VideoFile"
      file.save!
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/image.png")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      session[:flash_error].should  == "The type of file uploaded doesn't match the type of the existing file, which is a #{I18n.t("drs.display_labels.#{file.canonical_class}.short")}."
      @expected = {:url=>"/files/#{file.pid}/new"}.to_json
      response.body.should == @expected

      #canonical_class is "ImageMasterFile"
      file.canonical_class = "ImageMasterFile"
      file.save!
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/test_two.pdf")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      session[:flash_error].should  == "The type of file uploaded doesn't match the type of the existing file, which is a #{I18n.t("drs.display_labels.#{file.canonical_class}.short")}."
      @expected = {:url=>"/files/#{file.pid}/new"}.to_json
      response.body.should == @expected
    end

    it "returns json error if the file does not pass virus check" do
      # not sure how to fake a failing virus check
    end

    it "assigns core_file" do
      sign_in admin
      file.canonical_class = "VideoFile"
      file.save!
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/video.mp4")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      assigns(:core_file).should == file
      VideoMasterFile.destroy_all
    end


    it "creates content object with canonical class from core file" do
      file.canonical_class = "VideoFile"
      file.save!
      sign_in admin
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/video.mp4")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      VideoMasterFile.all.count.should == 1
      VideoMasterFile.destroy_all
    end

    it "sets content_object as incomplete" do
      file.canonical_class = "VideoFile"
      file.save!
      sign_in admin
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/video.mp4")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      VideoMasterFile.first.properties.incomplete?.should be true
      VideoMasterFile.destroy_all
    end

    it "assigns tmp_path to content_object" do
      file.canonical_class = "VideoFile"
      file.save!
      sign_in admin
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/video.mp4")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      video = VideoMasterFile.first
      video.tmp_path.should_not == nil
      VideoMasterFile.destroy_all
    end

    it "assigns original_filename to content_object" do
      file.canonical_class = "VideoFile"
      file.save!
      sign_in admin
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/video.mp4")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      video = VideoMasterFile.first
      video.original_filename.should == test_file.original_filename
      VideoMasterFile.destroy_all
    end

    it "renders json url: files_provide_file_metadata_path(@core_file.pid, content_object.pid)" do
      file.canonical_class = "VideoFile"
      file.save!
      sign_in admin
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/video.mp4")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      video = VideoMasterFile.first
      @expected = {:url=>files_provide_file_metadata_path(file.pid, video.pid)}.to_json
      response.body.should == @expected
      VideoMasterFile.destroy_all
    end

    it "assigns depositor as current user if not a proxy upload" do
      file.canonical_class = "VideoFile"
      file.save!
      admin.add_group("northeastern:drs:repository:proxystaff")
      admin.save!
      sign_in admin
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/video.mp4")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1, upload_type:"proxy"
      video = VideoMasterFile.first
      video.proxy_uploader.should == admin.nuid
      video.depositor.should == bill.nuid
      VideoMasterFile.destroy_all
      admin.delete_group("northeastern:drs:repository:proxystaff")
    end

    it "assigns proxy_uploader as current user and depositor as core_file depositor if it is a proxy_upload" do
      file.canonical_class = "VideoFile"
      file.save!
      admin.add_group("northeastern:drs:repository:proxystaff")
      admin.save!
      sign_in admin
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/video.mp4")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1, upload_type:"personal"
      video = VideoMasterFile.first
      video.proxy_uploader.should be nil
      video.depositor.should == admin.nuid
      VideoMasterFile.destroy_all
      admin.delete_group("northeastern:drs:repository:proxystaff")
    end

    it "assigns depositor as current user if not proxystaff" do
      file.canonical_class = "VideoFile"
      file.save!
      sign_in admin
      get :new_attached_file, id:file.pid
      test_file = fixture_file_upload("/files/video.mp4")
      post :create_attached_file, id:file.pid, file:test_file, terms_of_service:1
      video = VideoMasterFile.first
      video.proxy_uploader.should be nil
      video.depositor.should == admin.nuid
      VideoMasterFile.destroy_all
    end
  end

  describe "GET #new_attached_file" do
    it "renders to new_attached_file template for admin users" do
      sign_in admin
      get :new_attached_file, id: file.pid
      expect(response).to render_template('core_files/new_attached_file')
    end

    it "403s for users not logged in" do
      sign_out bill
      sign_out bo
      sign_out admin
      get :new_attached_file, id: file.pid
      expect(response).to redirect_to(new_user_session_path)
    end

    it "403s for users that are not admins" do
      sign_in bo
      get :new_attached_file, id: file.pid
      response.status.should == 403
    end
  end
end
