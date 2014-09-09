require 'spec_helper'
require 'cancan/matchers'

describe Ability do

  describe "read" do
    let(:proxier)     { FactoryGirl.create(:proxier) }
    let(:not_proxier) { FactoryGirl.create(:user) }

    before(:all) { @file = FactoryGirl.create(:bills_complete_file) }

    it "allows proxied users to read everything" do
      @file.mass_permissions = 'private'
      @file.save!
      expect(Ability.new proxier).to be_able_to(:read, @file)
    end

    it "doesn't allow proxied users to edit everything" do
      expect(Ability.new(proxier)).not_to be_able_to(:edit, @file)
    end

    it "applies normally to non proxy users" do
      @file.mass_permissions = 'private'
      @file.save!

      # Public still can't read private files
      expect(Ability.new nil).not_to be_able_to(:read, @file)

      # Non proxy staff can't read private files
      expect(Ability.new not_proxier).not_to be_able_to(:read, @file)
    end

    after(:all) { @file.destroy }
  end
end
