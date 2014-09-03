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

    expect(Employee.all.length).to eq 1
  end

  it "creates an Employee with matching nuid and all associated required smart_collections" do
    nuid = run_job

    # Verify the Employee exists
    expect(Employee.exists_by_nuid? nuid).to be true

    # Lookup the employee
    employee = Employee.find_by_nuid(nuid)

    # Employee has six required smart_collections
    expect(employee.smart_collections.length).to eq 6

    # All required smart_collections were spun up
    expect(employee.user_root_collection.class).to eq Collection
    expect(bill.can?(:edit, employee.user_root_collection)).to be true

    # Employee is tagged as complete
    expect(employee.is_building?).to be false

    # Only one employee is created
    expect(Employee.all.length).to eq 1

    # Run the job again to make sure collections aren't recreated
    run_job

    # Look up employee again to ensure fresh state
    employee = Employee.find_by_nuid(nuid)

    # Verify that there are still only six smart collections
    expect(employee.smart_collections.length).to eq 6
  end
end
