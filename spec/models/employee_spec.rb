require 'spec_helper'

# To minimize the amount of time this test takes to run we start by spinning up our two folder bearing
# users in an initial before :all block.  One is meant for the deletion test.

describe Employee do 

  after :all do 
    User.destroy_all
  end

  describe "Employee creation" do
    before :each do 
      Resque.inline = true
      observed = FactoryGirl.create(:user) 
      @observed = Employee.find_by_nuid(observed.nuid) 
      Resque.inline = false 
    end

    it "occurs automatically on new user create" do
      @observed.should be_an_instance_of Employee  
    end 

    it "generates personal folders" do

      @observed.folders.length.should == 6

      # This is the root of a user's personal item graph.
      @observed.root_folder.should be_an_instance_of NuCollection
      @observed.root_folder.personal_folder_type.should == 'user root' 

      # Directory for an employee's research publications.
      @observed.research_publications.should be_an_instance_of NuCollection
      @observed.research_publications.personal_folder_type.should == 'research publications'

      # Other publications an employee might've created.
      @observed.other_publications.should be_an_instance_of NuCollection
      @observed.other_publications.personal_folder_type.should == 'other publications'

      # Data sets for research an employee might've performed.
      @observed.data_sets.should be_an_instance_of NuCollection
      @observed.data_sets.personal_folder_type.should == 'data sets' 

      # Presentations an employee might've prepared.
      @observed.presentations.should be_an_instance_of NuCollection
      @observed.presentations.personal_folder_type.should == 'presentations'

      # Teaching aides an employee might've created.
      @observed.learning_objects.should be_an_instance_of NuCollection
      @observed.learning_objects.personal_folder_type.should == 'learning objects' 
    end
  end

  describe "Employee search" do

    it "can find employees via their nuid" do
      a = Employee.create(nuid: "find_me", name: "Will")   
      Employee.find_by_nuid("find_me").pid.should == a.pid 
    end

    it "throws a NoSuchNuidError when no results are returned" do 
      expect { Employee.find_by_nuid("nosuchnuid") }.to raise_error Employee::NoSuchNuidError 
    end

    it "throws a MultipleMatchError when more than one result is returned" do
      Employee.create(nuid: "one") 
      Employee.create(nuid: "one") 

      expect { Employee.find_by_nuid("one") }.to raise_error Employee::MultipleMatchError 
    end

    it "can handle queries with colons" do 
      a = Employee.create(nuid: "colon:colon:colon:::") 

      Employee.find_by_nuid("colon:colon:colon:::").pid.should == a.pid 
    end

    it "can handle queries with strings" do 
      a = Employee.create(nuid: " space space space ") 
      Employee.find_by_nuid(" space space space ").pid.should == a.pid 
    end
  end

  # describe "Personal folders" do

  #   it "can be added by the user" do 
  #     employee = Employee.find(@employee.pid) 

  #     employee.folders.length.should == 8 
  #   end

  #   it "off of root can be found with self.personal_folders" do

  #     employee = Employee.find(@employee.pid)
  #     personal_folders = employee.personal_folders

  #     personal_folders.length.should == 1
  #     personal_folders.first.title.should == "Off Root" 
  #   end
  # end


  # describe "Employee deletion" do

  #   it "eliminates the employees personal graph" do
  #     destroyed_pid = @destroyed.pid 
  #     graph_pids = @destroyed.folders.map { |f| f.pid } 

  #     @destroyed.destroy

  #     expect { Employee.find(destroyed_pid) }.to raise_error ActiveFedora::ObjectNotFoundError 

  #     graph_pids.each do |pid| 
  #       expect { ActiveFedora::Base.find(pid) }.to raise_error ActiveFedora::ObjectNotFoundError 
  #     end
  #   end
  # end
end