require 'spec_helper'

describe UsersController do
  let(:bill) { FactoryGirl.create(:bill) }

  describe "#update" do
    it "should update the users view_pref if logged in" do
      sign_in bill
      bill.view_pref  = "grid"
      expect(bill.view_pref == "grid")
      put :update, id: bill,  view_pref: 'list'
      expect(bill.view_pref == 'list')
    end

  end
end
