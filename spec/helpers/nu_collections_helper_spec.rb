require 'spec_helper'

# Specs in this file have access to a helper object that includes
# the NuCollectionsHelper. For example:
#
# describe NuCollectionsHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
describe NuCollectionsHelper do
  let(:bill) { FactoryGirl.create(:bill) }
  let(:parent) { FactoryGirl.create(:valid_owned_by_bill) }

  before :all do
    User.destroy_all
  end

  describe "#filtered_permissions" do
    true
  end

  describe "#render_upload_files_button" do
    it "returns a link to the new file path if the permissions are correct" do
      helper.stub(:current_user) { bill }
      expect(helper.render_upload_files_button(parent)).to eq "<a href=\"/files/new?parent=neu%3A#{(parent.pid).split(":").last}\">Upload files to this collection</a>"
    end
  end

  describe "#render_create_collection_button" do
    true
  end

  describe "#render_delete_object_button" do
    true
  end
end
