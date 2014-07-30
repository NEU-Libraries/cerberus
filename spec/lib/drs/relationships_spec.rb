require 'spec_helper'

describe Drs::Relationships do

  before :all do
    Employee.destroy_all
  end

  let(:rel_parent) { RelationshipHelper.create }
  let(:community) { FactoryGirl.create(:community) }
  let(:employee)   { FactoryGirl.create(:employee) }
  let(:rel_helper) { RelationshipHelper.new }

  # Helper class implementing the module.
  class RelationshipHelper < ActiveFedora::Base
    include Drs::Relationships

    has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream

    belongs_to :parent, property: :is_member_of, class_name: "RelationshipHelper"
    belongs_to :dept, property: :is_member_of, class_name: "Community"
    belongs_to :employee, property: :is_member_of, class_name: "Employee"

    def parent=(val)
      unique_assign_by_string(val, :is_member_of, [RelationshipHelper, Community], allow_nil: true)
    end

    def parent
      single_lookup(:is_member_of, [RelationshipHelper, Community])
    end

    def employee=(val)
      unique_assign_by_string(val, :is_member_of, [Employee])
    end

    def employee
      single_lookup(:is_member_of, [Employee])
    end
  end

  describe "Assignment" do
    it "allows us to assign multiple classes for a given relationship" do
      rel_helper.parent = community
      rel_helper.parent.should == community

      rel_helper.parent = rel_parent.pid
      rel_helper.parent.should == rel_parent
    end

    it "scrubs the previous entry for a given relationship" do
      rel_helper.parent = community.pid
      rel_helper.parent = rel_parent

      rel_helper.relationships(:is_member_of).length.should == 1
    end

    it "allows nil for for assignments with allow_nil: true" do
      rel_helper.parent = nil
      rel_helper.parent.should be nil
    end

    it "scrubs previous entries when nil is assigned" do
      rel_helper.parent = community
      rel_helper.parent = nil

      rel_helper.relationships(:is_member_of).length.should == 0
    end

    it "disallows nil for assignments without allow_nil: true" do
      expect{ rel_helper.employee = nil}.to raise_error
    end

    it "disallows incorrect class assignment" do
      expect { rel_helper.employee = collection }.to raise_error
      expect { rel_helper.employee = community }.to raise_error
      expect { rel_helper.employee = employee }.to_not raise_error
    end
  end
end
