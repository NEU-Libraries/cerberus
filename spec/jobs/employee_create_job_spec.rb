require 'spec_helper'


describe EmployeeCreateJob do

  let(:bill) { FactoryGirl.create(:bill) }
  let(:bo) { FactoryGirl.create(:bo) }

  let(:run_job) do
    EmployeeCreateJob.new(bill.nuid, "Joe Blow").run
    return bill.nuid
  end

  before(:each) do
    Employee.all.map { |e| e.destroy }
  end

  it "doesn't create multiple employees if one already exists" do
    Employee.create(nuid: bo.nuid)
    EmployeeCreateJob.new(bo.nuid, "Frank Buckets").run

    Employee.all.length.should == 1
  end

  it "creates an Employee with matching nuid and all associated required smart_collections" do
    nuid = run_job

    # Verify the Employee exists
    Employee.exists_by_nuid?(nuid).should be true

    # Lookup the employee
    employee = Employee.find_by_nuid(nuid)

    # Employee has six required smart_collections
    employee.smart_collections.length.should == 6

    # All required smart_collections were spun up
    employee.user_root_collection.should be_an_instance_of NuCollection
    bill.can?(:edit, employee.user_root_collection).should be true

    # Employee is tagged as complete
    employee.is_building?.should be false

    # Only one employee is created
    Employee.all.length.should == 1
  end
end
