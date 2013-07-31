require 'spec_helper' 

describe CrudDatastream do

  before do 
    @crud = CrudDatastream.new()
  end

  subject { @crud } 

  it { should respond_to(:to_xml) } 
  it { should respond_to(:add_create_perm) } 
  it { should respond_to(:remove_create_perm) } 
  it { should respond_to(:add_read_perm) } 
  it { should respond_to(:remove_read_perm) } 
  it { should respond_to(:add_update_perm) } 
  it { should respond_to(:remove_update_perm) } 
  it { should respond_to(:add_destroy_perm) } 
  it { should respond_to(:remove_destroy_perm) }

  describe "Adding perms" do

    before do 
      @set_crud = CrudDatastream.new
    end

    describe "Adding multiple perms" do 
      
      before do 
        @set_crud.add_create_perm('individual', "Stibbons, Ponder")
        @set_crud.add_create_perm('group', "UU:All") 
      end

      it "Has two permissions" do 
        @set_crud.create_root.identity.length.should == 2 
      end

      it "Has both users" do 
        @set_crud.create_root.identity.should == ["Stibbons, Ponder", "UU:All"]
      end

      it "Has set only one permission for Mr. Stibbons" do 
        @set_crud.create_root.identity(0).identity_type.length.should == 1
      end

      it "Has set the correct single permission for Mr. Stibbons" do 
        @set_crud.create_root.identity(0).identity_type.first.should == 'individual'
      end

      it "Has set only one permission for the UU body" do 
        @set_crud.create_root.identity(1).identity_type.length.should == 1
      end

      it "Has set the correct single permission for the UU body" do 
        @set_crud.create_root.identity(1).identity_type.first.should == 'group' 
      end
    end

    describe "Adding an identical perm" do 

      it "Adds a new perm without issue" do 
        @set_crud.add_read_perm('individual', "Stibbons, Ponder")
      end

      it "Fails to add the same perm twice" do
        @set_crud.add_read_perm('individual', "Stibbons, Ponder") 
        expect { @set_crud.add_read_perm('individual', "Stibbons, Ponder") }.to raise_error
      end
    end 
  end

  describe "Removing perms" do 
    before do 
      @removal_crud = CrudDatastream.new()
      @removal_crud.add_create_perm('individual', 'Stibbons, Ponder') 
      @removal_crud.add_create_perm('individual', 'Librarian, The') 
      @removal_crud.add_read_perm('group', 'UU:Faculty') 
      @removal_crud.add_read_perm('individual', 'Vimes, Samuel') 
      @removal_crud.add_update_perm('individual', 'Ridcully, Mustrum') 
      @removal_crud.add_update_perm('individual', 'Stibbons, Ponder') 
      @removal_crud.add_update_perm('individual', 'Librarian, The') 
      @removal_crud.add_destroy_perm('individual', 'Stibbons, Ponder')
      @removal_crud.add_destroy_perm('individual', 'Librarian, The')
      @removal_crud.add_destroy_perm('individual', 'Rincewind') 
    end

    it "Returns false when we attempt to remove perms that don't exist" do 
      @removal_crud.remove_create_perm('individual', 'Doe, John').should be false 
    end

    it "Returns true when a removal succeeds" do 
      @removal_crud.remove_update_perm('individual', 'Ridcully, Mustrum').should be true  
    end

    #A permission can only be added if it isn't identical to one already in the datastream
    it "Removes the correct permission" do
      @removal_crud.remove_update_perm('individual', 'Ridcully, Mustrum')  
      @removal_crud.add_update_perm('individual', 'Ridcully, Mustrum') 
    end
  end
end