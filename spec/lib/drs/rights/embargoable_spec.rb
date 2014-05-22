require 'spec_helper'

describe Drs::Rights::Embargoable do
  before :all do
    User.all.each do |user|
      user.destroy
    end
  end

  let(:embargoed_collection) { NuCollection.new }
  let(:no_embargo) { NuCollection.new }
  let(:bill) { FactoryGirl.create(:bill) }
  let(:bo) { FactoryGirl.create(:bo) }

  describe "Embargo" do

    before(:each) do
      embargoed_collection.embargo_release_date = Date.tomorrow
      embargoed_collection.depositor = bill.nuid
    end

    it "blocks access for users who aren't the depositor" do
      embargoed_collection.embargo_in_effect?(bo).should be true
    end

    it "doesn't block access for the depositor " do
      embargoed_collection.embargo_in_effect?(bill).should be false
    end

    it "blocks access for non-authenticated (public) users" do
      embargoed_collection.embargo_in_effect?(nil).should be true
    end

    it "doesn't block access to non-embargoed items" do
      no_embargo.embargo_in_effect?(bo).should be false
    end

    it "doesn't block access to non-embargoed items for the depositor" do
      no_embargo.embargo_in_effect?(bill).should be false
    end

    it "doesn't block access to non-embargoed items for the general public" do
      no_embargo.embargo_in_effect?(nil).should be false
    end
  end
end
