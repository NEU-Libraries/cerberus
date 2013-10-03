require 'spec_helper' 


describe EmployeeCreateJob do 

  # Guarantees uniqueness, even if using system noids as nuid's is a little weird. 
  let(:run_job) do
    pid = Sufia::Noid.namespaceize(Sufia::IdService.mint)  
    EmployeeCreateJob.new(pid).run 
    return pid 
  end

  before(:each) do 
    Employee.all.map { |e| e.destroy } 
  end

  it "creates an Employee with matching nuid and all associated required folders" do 
    nuid = run_job 

    # Verify the Employee exists
    Employee.exists_by_nuid?(nuid).should be true

    # Lookup the employee
    employee = Employee.find_by_nuid(nuid) 

    # Employee has six required folders
    employee.folders.length.should == 6 

    # All required folders were spun up
    employee.root_folder.should be_an_instance_of NuCollection
    employee.research_publications.should be_an_instance_of NuCollection 
    employee.other_publications.should be_an_instance_of NuCollection
    employee.data_sets.should be_an_instance_of NuCollection
    employee.presentations.should be_an_instance_of NuCollection
    employee.learning_objects.should be_an_instance_of NuCollection 

    # Employee is tagged as complete 
    employee.is_building?.should be false

    # Only one employee is created 
    Employee.all.length.should == 1  
  end
end