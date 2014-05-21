require 'spec_helper'

describe Employee do

  before :each do
    Employee.destroy_all
  end

  describe "validation" do
    it "disallows multiple employees with the same nuid" do
      a = Employee.create(nuid: "multiples@employeespec.com")

      Employee.find_by_nuid(a.nuid).pid.should == a.pid
      Employee.new(nuid: "multiples@employeespec.com").valid?.should be false
    end

    it "allows updating of employee objects" do
      a = Employee.create(nuid: "updated@updated.com")
      a.nuid = "actuallyupdated@updated.com"
      a.save!

      a.nuid.should == "actuallyupdated@updated.com"
    end
  end

  describe "community attachment" do
    let(:employee)      { FactoryGirl.create :employee }
    let(:community)     { FactoryGirl.create :community }
    let(:community_two) { FactoryGirl.create :community}

    it "adds communities" do
      employee.add_community(community)
      employee.save!

      employee.communities.should == [community]
    end

    it "removes communities" do
      employee.add_community(community)
      employee.add_community(community_two)
      employee.save!

      employee.remove_community(community)
      employee.save!

      employee.communities.should == [community_two]
    end

    it "writes community names to the details datastream on save" do
      employee.add_community(community)
      employee.add_community(community_two)

      employee.save!
      expected_array = [community.title, community_two.title]

      employee.details.community_name.should == expected_array
    end
  end

  describe "search" do
    it "can find employees via their nuid" do
      a = Employee.create(nuid: "findme@examples.com")

      Employee.find_by_nuid("findme@examples.com").pid.should == a.pid
    end

    it "raises an error if no Employee with the given nuid exists" do
      expect { Employee.find_by_nuid("neu:nopenope") }.to raise_error Exceptions::NoSuchNuidError
    end
  end

  describe "solrization" do
    let(:employee) { Employee.new }
    let(:solr) { employee.to_solr }

    context "with no employee name set" do

      it "doesn't raise an exception" do
        expect { employee.to_solr }.not_to raise_error
      end

      it "assigns it a nil value" do
        solr["employee_name_tesim"].should be nil
      end
    end

    context "with no employee nuid set" do

      it "doesn't raise an exception" do
        expect { employee.to_solr }.not_to raise_error
      end

      it "assigns it a nil value" do
        solr["employee_nuid_ssim"].should be nil
      end
    end

    context "with name and nuid set" do
      before(:each) do
        employee.name = "Will"
        employee.nuid = "000111222"
      end

      it "sets the name" do
        solr["employee_name_tesim"].should == "Will"
      end

      it "sets the nuid" do
        solr["employee_nuid_ssim"].should == "000111222"
      end
    end

    context "of community name field" do
      before(:each) do
        employee.details.community_name = ["English", "Math"]
      end

      it "sets the community name" do
        solr["community_name_ssim"].should == ["English", "Math"]
      end
    end
  end

  after :all do
    Employee.destroy_all
  end
end
