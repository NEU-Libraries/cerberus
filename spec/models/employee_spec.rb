require 'spec_helper'

RSpec.configure do |config|
  config.before(:all) do 
    Resque.inline = true 
  end
end

describe Employee do 
  
  let(:employee) do 
    a = FactoryGirl.create(:user) 
    employee = Employee.find_by_nuid(a.nuid)
    return employee
  end

  describe "Employee creation" do 
    it "occurs automatically on new user create" do 
      employee.should_not be nil 
    end 

    it "generates personal folders" do 
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
    it "can be achieved via nuid" do 
      nuid = employee.nuid 

      Employee.find_by_nuid(nuid).pid.should == employee.pid 
    end
  end
end