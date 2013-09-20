require 'spec_helper'

describe Employee do
  describe "search" do
    it "can find employees via their nuid" do
      a = Employee.create(nuid: "findme@examples.com")

      Employee.find_by_nuid("findme@examples.com").pid.should == a.pid 
    end

    it "raises an error if no Employee with the given nuid exists" do 
      expect { Employee.find_by_nuid("neu:nopenope") }.to raise_error Employee::NoSuchNuidError 
    end

    it "raises an error if multiple Employees with the given nuid exist" do 
      Employee.create(nuid: "neu:multiples") 
      Employee.create(nuid: "neu:multiples") 

      expect { Employee.find_by_nuid("neu:multiples") }.to raise_error Employee::MultipleMatchError 
    end
  end
end