require 'spec_helper'

# Conditional application of the Resque.inline command on these tests 
# makes them surprisingly brittle.  Hence the use of describe block specific models
# that are manually cleaned out at block conclusion. 

describe Employee do

  # This shouldn't be necessary but it do.  
  # Note that this kludge doesn't seem to be required on the front end
  def super_safe_employee_lookup(nuid) 
    employee = Employee.find_by_nuid(nuid)

    if !employee.folders.length == 6 
      i = 0
      while i <= 4
        sleep 4
        employee = Employee.find_by_nuid(nuid)
        if employee.folders.length == 6 
          return employee
          exit 
        end
      end
    end
    return employee
  end

  describe "creation" do

    before :all do
      ActiveFedora::Base.all.map { |n| n.destroy } 
      User.all.map { |x| x.destroy }

      Resque.inline = true
      a = User.create(email: "creation@examples.com", password: "password1")
      sleep 5
      Resque.inline = false
    end

    after :all do
      ActiveFedora::Base.all.map { |n| n.destroy } 
      User.all.map { |x| x.destroy } 
    end

    it "generates personal folders" do
      creation = super_safe_employee_lookup("creation@examples.com") 

      creation.folders.length.should == 6

      # This is the root of a user's personal item graph.
      creation.root_folder.should be_an_instance_of NuCollection
      creation.root_folder.personal_folder_type.should == 'user root' 

      # Directory for an employee's research publications.
      creation.research_publications.should be_an_instance_of NuCollection
      creation.research_publications.personal_folder_type.should == 'research publications'

      # Other publications an employee might've created.
      creation.other_publications.should be_an_instance_of NuCollection
      creation.other_publications.personal_folder_type.should == 'other publications'

      # Data sets for research an employee might've performed.
      creation.data_sets.should be_an_instance_of NuCollection
      creation.data_sets.personal_folder_type.should == 'data sets' 

      # Presentations an employee might've prepared.
      creation.presentations.should be_an_instance_of NuCollection
      creation.presentations.personal_folder_type.should == 'presentations'

      # Teaching aides an employee might've created.
      creation.learning_objects.should be_an_instance_of NuCollection
      creation.learning_objects.personal_folder_type.should == 'learning objects' 
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

    it "raises an error if multiple Employees with the given nuid exist" do 
      Employee.create(nuid: "neu:multiples") 
      Employee.create(nuid: "neu:multiples") 

      expect { Employee.find_by_nuid("neu:multiples") }.to raise_error Employee::MultipleMatchError 
    end
  end


  describe "deletion" do
    before :all do
      puts "executing deletion before hook."
      ActiveFedora::Base.all.map { |x| x.destroy } 
      User.all.map { |u| u.destroy } 
      Resque.inline = true
      @usr = User.create(email:"deletion@examples.com", password: "password1")
      sleep 5
      Resque.inline = false
    end 

    after :all do 
      ActiveFedora::Base.all.map { |x| x.destroy } 
      User.all.map { |u| u.destroy } 
    end

    it "eliminates the employees personal graph on employee delete" do
      deletion = super_safe_employee_lookup("deletion@examples.com")  

      employee_pid = deletion.pid 
      graph_pids = deletion.folders.map { |f| f.pid } 

      @usr.destroy

      expect { Employee.find(employee_pid) }.to raise_error ActiveFedora::ObjectNotFoundError 

      graph_pids.each do |pid| 
        expect { ActiveFedora::Base.find(pid) }.to raise_error ActiveFedora::ObjectNotFoundError 
      end
    end
  end
end