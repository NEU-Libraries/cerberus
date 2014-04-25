require 'spec_helper'


describe EmployeeCreateJob do

  # Guarantees uniqueness, even if using system noids as nuid's is a little weird.
  let(:run_job) do
    pid = Sufia::Noid.namespaceize(Sufia::IdService.mint)
    EmployeeCreateJob.new(pid, "Joe Blow").run
    return pid
  end

  before(:each) do
    Employee.all.map { |e| e.destroy }
  end

  it "doesn't create multiple employees if one already exists" do
    pid = Sufia::Noid.namespaceize(Sufia::IdService.mint)
    Employee.create(nuid: pid)
    EmployeeCreateJob.new(pid, "Frank Buckets").run

    Employee.all.length.should == 1
  end

  it "creates an Employee with matching nuid and all associated required smart_collections" do
    nuid = run_job

    # Verify the Employee exists
    Employee.exists_by_nuid?(nuid).should be true
    user = User.create(email: nuid, nuid: nuid)

    # Lookup the employee
    employee = Employee.find_by_nuid(nuid)

    # Employee has six required smart_collections
    employee.smart_collections.length.should == 6

    # All required smart_collections were spun up
    employee.user_root_collection.should be_an_instance_of NuCollection
    user.can?(:edit, employee.user_root_collection).should be true

    employee.research_publications_collection.should be_an_instance_of SolrDocument
    user.can?(:edit, employee.research_publications_collection).should be true

    employee.other_publications_collection.should be_an_instance_of SolrDocument
    user.can?(:edit, employee.other_publications_collection).should be true

    employee.datasets_collection.should be_an_instance_of SolrDocument
    user.can?(:edit, employee.datasets_collection).should be true

    employee.presentations_collection.should be_an_instance_of SolrDocument
    user.can?(:edit, employee.presentations_collection).should be true

    employee.learning_objects_collection.should be_an_instance_of SolrDocument
    user.can?(:edit, employee.learning_objects_collection).should be true

    # Employee is tagged as complete
    employee.is_building?.should be false

    # Only one employee is created
    Employee.all.length.should == 1
  end
end
