require 'spec_helper'

describe Employee do 
  before(:each) do
    Resque.inline = true 
    a = FactoryGirl.create(:user) 
    @employee = Employee.find_by_nuid(a.nuid) 
    Resque.inline = false
  end

  describe "Employee creation" do 
    it "occurs automatically on new user create" do
      employee = @employee

      employee.should_not be nil 
    end 

    it "generates personal folders" do
      employee = @employee

      employee.folders.length.should == 6

      # This is the root of a user's personal item graph.
      employee.root_folder.should be_an_instance_of NuCollection
      employee.root_folder.personal_folder_type.should == 'user root' 

      # Directory for an employee's research publications.
      employee.research_publications.should be_an_instance_of NuCollection
      employee.research_publications.personal_folder_type.should == 'research publications'

      # Other publications an employee might've created.
      employee.other_publications.should be_an_instance_of NuCollection
      employee.other_publications.personal_folder_type.should == 'other publications'

      # Data sets for research an employee might've performed.
      employee.data_sets.should be_an_instance_of NuCollection
      employee.data_sets.personal_folder_type.should == 'data sets' 

      # Presentations an employee might've prepared.
      employee.presentations.should be_an_instance_of NuCollection
      employee.presentations.personal_folder_type.should == 'presentations'

      # Teaching aides an employee might've created.
      employee.learning_objects.should be_an_instance_of NuCollection
      employee.learning_objects.personal_folder_type.should == 'learning objects' 
    end
  end

  describe "Employee search" do 
    it "can find employees via their nuid" do
      employee = @employee

      nuid = employee.nuid 

      Employee.find_by_nuid(nuid).pid.should == employee.pid 
    end
  end

  describe "Employee deletion" do 
    it "eliminates the employees personal graph" do
      employee = @employee
      employee_pid = employee.pid 
      graph_pids = employee.folders.map { |f| f.pid } 

      employee.destroy

      expect { Employee.find(employee_pid) }.to raise_error ActiveFedora::ObjectNotFoundError 

      graph_pids.each do |pid| 
        expect { ActiveFedora::Base.find(pid) }.to raise_error ActiveFedora::ObjectNotFoundError 
      end
    end
  end
end