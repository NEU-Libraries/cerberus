require 'spec_helper'

describe CoreFilesController do
  let(:bill) { FactoryGirl.create(:bill) }
  let(:bo)   { FactoryGirl.create(:bo) }
  let(:root) { FactoryGirl.create(:root_collection) }

  let(:file) { FactoryGirl.create(:complete_file,
                                  depositor: "000000001",
                                  parent: root) }

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
      file.impression_views.should == 1
    end

    it "only writes a single impression on multiple hits" do
      sign_in bill

      get :show, { id: file.pid }
      get :show, { id: file.pid }

      ImpressionProcessingJob.new().run
      Impression.count.should == 1
      file.impression_views.should == 1
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
end
