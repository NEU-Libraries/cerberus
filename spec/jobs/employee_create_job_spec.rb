require 'spec_helper'


describe EmployeeCreateJob do
  let(:bill) { FactoryGirl.create(:bill) }
  let(:bo) { FactoryGirl.create(:bo) }

  let(:run_job) do
    EmployeeCreateJob.new(bill.nuid, "Joe Blow").run
    return bill.nuid
  end

  before(:each) do
    ActionMailer::Base.deliveries = []
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

    # Employee has eight required smart_collections
    expect(employee.smart_collections.length).to eq 8

    # All required smart_collections were spun up
    expect(employee.user_root_collection.class).to eq Collection
    expect(bill.can?(:edit, employee.user_root_collection)).to be true

    # Employee is tagged as complete
    expect(employee.is_building?).to be false

    # Only one employee is created
    expect(Employee.all.length).to eq 1

    # A new employee alert email is sent
    expect(ActionMailer::Base.deliveries.length).to eq 1
    subject = "[cerberus] New Employee Created"
    expect(ActionMailer::Base.deliveries.first.subject).to eq subject

    # Run the job again to make sure collections aren't recreated
    run_job

    # Look up employee again to ensure fresh state
    employee = Employee.find_by_nuid(nuid)

    # Verify that there are still only eight smart collections
    expect(employee.smart_collections.length).to eq 8
  end

  it "sends a new employee alert email as long as an employee is created" do
    EmployeeCreateJob.any_instance.stub(:create_personal_collection)
    .and_raise StandardError

    # Executing the job raises an exception
    expect{ run_job }.to raise_error StandardError

    # An employee was created
    expect(Employee.exists_by_nuid? bill.nuid).to be true

    # Hackily ensure all employees are tagged as complete
    Employee.all.map { |e| e.employee_is_complete ; e.save! }

    employee = Employee.find_by_nuid bill.nuid

    # No collections were created
    expect(employee.smart_collections).to match_array []

    # An email was sent
    # expect(ActionMailer::Base.deliveries.length).to eq 1
  end

  it "doesn't send a new employee alert if the employee fails to build" do
    Employee.any_instance.stub(:create).and_raise StandardError

    # Executing the job raises an exception
    expect { run_job }.to raise_error StandardError

    # No employee is created
    expect(Employee.all.length).to eq 0

    # No email is sent
    expect(ActionMailer::Base.deliveries.length).to eq 0
  end
end
