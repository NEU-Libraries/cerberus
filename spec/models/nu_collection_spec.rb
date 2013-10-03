require 'spec_helper' 

describe NuCollection do 

  let(:collection) { NuCollection.new } 

  describe "Custom setters and getters" do
    let(:c) { NuCollection.new } 

    it "Sets custom permissions correctly" do 
      permissions = {'permissions0' => {'identity_type' => 'person', 'identity' => 'Will', 'permission_type' => 'edit'}, 
                      'permissions1' => {'identity_type' => 'group', 'identity' => 'NU:All', 'permission_type' => 'read'},
                      'permissions2' => {'identity_type' => 'person', 'identity' => 'Tadd', 'permission_type' => 'read'} }
      c.permissions = permissions 
      c.permissions.should =~ [{ type: 'user', access: 'edit', name: 'Will' },
                               { type: 'group', access: 'read', name: 'NU:All' }, 
                               { type: 'user', access: 'read', name: 'Tadd'}]
    end

    it "Doesn't allow permissions set of public or registered groups" do 
      permissions = {'permissions0' => {'identity_type' => 'group', 'identity' => 'public', 'permission_type' => 'read'},
                      'permissions1' => {'identity_type' => 'group', 'identity' => 'registered', 'permission_type' => 'read'},
                      'permissions2' => {'identity_type' => 'group', 'identity' => 'public', 'permission_type' => 'edit'}, 
                      'permissions3' => {'identity_type' => 'group', 'identity' => 'registered', 'permission_type' => 'edit'} }
      c.permissions = permissions 
      c.permissions.should == []
    end 
  end

  describe "Behavior of Parent setter" do 
    let(:p_coll) { NuCollection.new }
    let(:root) { NuCollection.new }

    before do
      root.save! 
      @saved_root = NuCollection.find(root.pid) 
    end 

    it "Sets the parent collection, but receives nil" do 
      p_coll.parent = @saved_root.pid 
      p_coll.parent.should == @saved_root 
    end
  end

  describe "User parent" do 
    let(:employee) { FactoryGirl.create(:employee) }

    it "can be set via nuid" do 
      collection.user_parent = employee.nuid 
      collection.user_parent.pid.should == employee.pid 
    end

    it "CANNOT be set by pid" do 
      expect{collection.user_parent = employee.pid}.to raise_error 
    end

    it "can be set by passing the entire object" do 
      collection.user_parent = employee 
      collection.user_parent.pid.should == employee.pid 
    end
  end 


  describe "Recursive delete" do 
    before(:each) do
      ActiveFedora::Base.find(:all).each do |file| 
        file.destroy 
      end

      @root = NuCollection.create(title: "Root") 
      @child_one = NuCollection.create(title: "Child One", parent: @root) 
      @c1_gf = NuCoreFile.create(title: "Core File One", parent: @child_one, depositor: "nobody@nobody.com") 
      @c2_gf = NuCoreFile.create(title: "Core File Two", parent: @child_one, depositor: "nobody@nobody.com")  
      @child_two = NuCollection.create(title: "Child Two", parent: @root) 
      @grandchild = NuCollection.create(title: "Grandchild", parent: @child_two) 
      @great_grandchild = NuCollection.create(title: "Great Grandchild", parent: @grandchild) 
      @gg_gf = NuCoreFile.create(title: "GG CF", parent: @great_grandchild, depositor: "nobody@nobody.com")
      @pids = [ @root.pid, @child_one.pid, @c1_gf.pid, @c2_gf.pid, @child_two.pid, @grandchild.pid, @great_grandchild.pid,
                @gg_gf.pid] 
    end

    it "deletes the item its called on and all descendent files and collections." do 
      @root.recursive_delete 

      NuCollection.find(:all).length.should == 0 
      NuCoreFile.find(:all).length.should == 0 
    end
  end

  after :all do 
    NuCollection.find(:all).each do |coll| 
      coll.destroy 
    end  
  end
end