require 'spec_helper'

describe UploadAlert do

  describe "querying" do
    before :all do
      FactoryGirl.create_list(:theses_alert, 2)
      FactoryGirl.create_list(:theses_update_alert, 2)
      FactoryGirl.create(:theses_notified_alert)

      FactoryGirl.create_list(:research_alert, 2)
      FactoryGirl.create_list(:research_update_alert, 2)
      FactoryGirl.create(:research_notified_alert)

      FactoryGirl.create_list(:presentation_alert, 2)
      FactoryGirl.create_list(:presentation_update_alert, 2)
      FactoryGirl.create(:presentation_notified_alert)

      FactoryGirl.create_list(:dataset_alert, 2)
      FactoryGirl.create_list(:dataset_update_alert, 2)
      FactoryGirl.create(:dataset_notified_alert)

      FactoryGirl.create_list(:learning_object_alert, 2)
      FactoryGirl.create_list(:learning_object_update_alert, 2)
      FactoryGirl.create(:learning_object_notified_alert)
    end

    after(:all) { UploadAlert.destroy_all }

    shared_examples_for "withheld queries" do
      it "return the correct number of results" do
        created.size.should == 2
        updated.size.should == 2
      end

      it "return the change type asked for" do
        created.all? { |x| x.change_type == "create" }.should be true
        updated.all? { |x| x.change_type == "update" }.should be true
      end
    end

    context "for research publications" do
      let(:created) { UploadAlert.withheld_research_publications(:create) }
      let(:updated) { UploadAlert.withheld_research_publications(:update) }

      it_should_behave_like "withheld queries"
    end

    context "for theses alerts" do
      let(:created) { UploadAlert.withheld_theses(:create) }
      let(:updated) { UploadAlert.withheld_theses(:update) }

      it_should_behave_like "withheld queries"
    end

    context "for presentation alerts" do
      let(:created) { UploadAlert.withheld_presentations(:create) }
      let(:updated) { UploadAlert.withheld_presentations(:update) }

      it_should_behave_like "withheld queries"
    end

    context "for dataset alerts" do
      let(:created) { UploadAlert.withheld_datasets(:create) }
      let(:updated) { UploadAlert.withheld_datasets(:update) }

      it_should_behave_like "withheld queries"
    end

    context "for learning object alerts" do
      let(:created) { UploadAlert.withheld_learning_objects(:create) }
      let(:updated) { UploadAlert.withheld_learning_objects(:update) }

      it_should_behave_like "withheld queries"
    end

    context "for other publications alerts" do
      let(:created) { UploadAlert.withheld_other_pubs(:create) }
      let(:updated) { UploadAlert.withheld_other_pubs(:update) }

      it_should_behave_like "withheld queries"
    end
  end


  describe "creation from core file" do
    before :all do
      @user = FactoryGirl.create(:bill)
      @core = FactoryGirl.create(:bills_complete_file)

      @parent = FactoryGirl.create(:root_collection)

      @core.parent = @parent
      @core.category =  "Theses and Dissertations"
      @core.save!
    end

    after(:all) { @user.destroy ; @core.destroy }

    def create_alert(change_type)
      @alert = UploadAlert.create_from_core_file(@core, change_type)
    end

    context "on core file creation" do
      before(:each) { create_alert(:create) }

      it "has a title" do
        @alert.title.should == @core.title
      end

      it "has a category" do
        @alert.depositor_email.should == @user.email
      end

      it "has a full name" do
        @alert.depositor_name.should == @user.full_name
      end

      it "has a pid" do
        @alert.pid.should == @core.pid
      end

      it "has a content type" do
        @alert.content_type.should == @core.category.first
      end

      it "has a change type" do
        @alert.change_type.should == :create
      end

      it "has a collection title" do
        @alert.collection_title.should == @core.parent.title
      end

      it "has a collection pid" do
        @alert.collection_pid.should == @core.parent.pid
      end
    end

    context "on core file update" do
      before(:each) { create_alert(:update) }

      it "has a change type" do
        @alert.change_type.should == :update
      end
    end

    context "with invalid change type" do

      it "raises an error" do
        expect{ UploadAlert.create_from_core_file(@core, 'edit') }.to raise_error
      end

      it "raises an error" do
        expect{ UploadAlert.create_from_core_file(@core, :edi) }.to raise_error
      end
    end
  end
end
