require 'spec_helper'

feature "per page" do
  let(:bill)             { FactoryGirl.create(:bill) }
  let(:root)             { FactoryGirl.create(:root_collection) }
  let(:bills_collection) { FactoryGirl.create(:bills_private_collection) }
  let(:file) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }
  let(:file2) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }
  let(:file3) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }
  let(:file4) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }
  let(:file5) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }
  let(:file6) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }
  let(:file7) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }
  let(:file8) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }
  let(:file9) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }
  let(:file10) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }
  let(:file11) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }
  let(:file12) { FactoryGirl.create(:complete_file, depositor: "000000001", parent: bills_collection) }

  describe "collections show" do
    it "alters the per_page_pref for a signed in user" do
      features_sign_in bill
      visit core_file_path(file.pid)
      visit core_file_path(file2.pid)
      visit core_file_path(file3.pid)
      visit core_file_path(file4.pid)
      visit core_file_path(file5.pid)
      visit core_file_path(file6.pid)
      visit core_file_path(file7.pid)
      visit core_file_path(file8.pid)
      visit core_file_path(file9.pid)
      visit core_file_path(file10.pid)
      visit core_file_path(file11.pid)
      visit core_file_path(file12.pid)
      visit collection_path(id: bills_collection.pid)
      current_path.should == "/collections/#{bills_collection.pid}"
      bill.per_page_pref.should == 10 #default value
      page.all('.drs-item').length.should == 10
      page.all('#per_page').length.should == 1
      #not testing the propogation of the JS, just if the per_page_pref is set
      bill.per_page_pref = 20
      bill.save!
      visit collection_path(id: bills_collection.pid)
      bill.per_page_pref.should == 20
      page.all('.drs-item').length.should == 12 #actually changes the amount show per page
      page.all('#per_page').length.should == 1
    end
  end

  after :all do
    ActiveFedora::Base.destroy_all
    User.destroy_all
  end
end
