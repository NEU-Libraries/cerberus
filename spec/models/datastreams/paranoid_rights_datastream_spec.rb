require 'spec_helper'

describe ParanoidRightsDatastream do

  before do
    @rights_ds = ParanoidRightsDatastream.new
  end

  subject { @rights_ds }

  describe "Embargos" do
    let(:embargoed) { ParanoidRightsDatastream.new }

    it "Doesn't allow non-parseable embargo dates" do
      embargoed.embargo_release_date = "Abbbrrgggl"
      embargoed.embargo_release_date.should == nil
    end

    it "Is under embargo if the date is in the future" do
      future_date = Date.tomorrow.to_s
      embargoed.embargo_release_date = future_date
      embargoed.under_embargo?.should be true
    end

    it "Is not under embargo if the date is in the past" do
      embargoed.embargo_release_date = "July 9, 1321"

      embargoed.under_embargo?.should be false
    end

    it "Does not throw an exception even when idiotic dates are entered" do
      embargoed.embargo_release_date = "Novtober 10, 2999"
      embargoed.under_embargo?.should be true

      embargoed.embargo_release_date = "Julune 9, 2010"
      embargoed.under_embargo?.should be false
    end
  end
end
