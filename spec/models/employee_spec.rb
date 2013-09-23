require 'spec_helper'

describe Employee do

  describe "validation" do 
    it "disallows multiple employees with the same nuid" do 
      a = Employee.create(nuid: "multiples@employeespec.com") 
      b = Employee.create(nuid: "multiples@employeespec.com") 

      Employee.find_by_nuid(a.nuid).pid.should == a.pid 
      Employee.new(nuid: "multiples@employeespec.com").valid?.should be false
    end
  end

  describe "search" do
    it "can find employees via their nuid" do
      a = Employee.create(nuid: "findme@examples.com")

      Employee.find_by_nuid("findme@examples.com").pid.should == a.pid 
    end

    it "raises an error if no Employee with the given nuid exists" do 
      expect { Employee.find_by_nuid("neu:nopenope") }.to raise_error Employee::NoSuchNuidError 
    end
  end
end