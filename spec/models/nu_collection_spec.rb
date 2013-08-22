require 'spec_helper' 

describe NuCollection do 

  let(:collection) { NuCollection.new } 

  subject { collection } 

  it { should respond_to(:title=) } 
  it { should respond_to(:title) } 
  it { should respond_to(:parent=) } 
  it { should respond_to(:parent) } 
  it { should respond_to(:identifier=) } 
  it { should respond_to(:identifier) } 
  it { should respond_to(:description=) }
  it { should respond_to(:description) }  
  it { should respond_to(:date_of_issue=) } 
  it { should respond_to(:date_of_issue) } 
  it { should respond_to(:keywords=) } 
  it { should respond_to(:keywords) } 
  it { should respond_to(:corporate_creators=) } 
  it { should respond_to(:corporate_creators) } 
  it { should respond_to(:personal_creators=) } 
  it { should respond_to(:personal_creators) } 
  it { should respond_to(:embargo_release_date=) } 
  it { should respond_to(:embargo_release_date) } 
  it { should respond_to(:permissions=) } 
  it { should respond_to(:permissions) } 
  it { should respond_to(:mass_permissions=) } 
  it { should respond_to(:mass_permissions) } 
  it { should respond_to(:embargo_in_effect?) } 
  it { should respond_to(:set_permissions_from_new_form) }

  describe "Custom setters and getters" do
    let(:c) { NuCollection.new } 

    it "Sets and fetches the proper title" do 
      c.title = "My Title" 
      c.title.should == "My Title" 
    end

    it "Sets and fetches the proper identifier" do 
      c.identifier = "neu:whatever" 
      c.identifier.should == "neu:whatever" 
    end

    it "Sets and fetches the proper description" do 
      c.description = "My dope description." 
      c.description.should == "My dope description." 
    end

    it "Sets and fetches the proper date of issue" do 
      c.date_of_issue = Date.yesterday.to_s 
      c.date_of_issue.should == Date.yesterday.to_s 
    end

    it "Sets and fetches the proper keyword array" do 
      c.keywords = ["one", "two", "three"] 
      c.keywords.should == ["one", "two", "three"] 
    end

    it "Sets and fetches the proper corporate creators" do 
      c.corporate_creators = ["c_one", "c_two", "c_three"] 
      c.corporate_creators.should == ["c_one", "c_two", "c_three"] 
    end

    it "Sets and fetches the proper personal creators" do 
      fns = ["Will", "Bill"]
      lns = ["Jackson", "Backson"]

      c.personal_creators = { 'creator_first_names' => fns, 'creator_last_names' => lns }
      c.personal_creators.should == [{ first: 'Will', last: 'Jackson' }, { first: 'Bill', last: 'Backson' }] 
    end

    it "Sets and fetches the proper embargo date" do 
      c.embargo_release_date = Date.tomorrow.to_s 
      c.embargo_release_date.should == Date.tomorrow.to_s 
    end

    it "Sets the 'public' mass permission correctly" do 
      c.mass_permissions = 'public'
      c.mass_permissions.should == 'public' 
    end

    it "Sets the 'registered' mass permission correctly" do 
      c.mass_permissions = 'registered' 
      c.mass_permissions.should == 'registered' 
    end

    it "Gets rid of public mass perm when registered is set" do 
      c.mass_permissions = 'public' 
      c.mass_permissions.should == 'public' 

      c.mass_permissions = 'registered' 
      c.mass_permissions.should == 'registered' 
      c.rightsMetadata.permissions({group: 'public'}).should == 'none' 
    end

    it "Gets rid of registered mass perm when public is set" do 
      c.mass_permissions = 'registered' 
      c.mass_permissions.should == 'registered' 

      c.mass_permissions = 'public' 
      c.mass_permissions.should == 'public' 
      c.rightsMetadata.permissions({group: 'registered'}).should == 'none' 
    end 

    it "Sets the 'private' mass permission correctly" do 
      c.mass_permissions = 'private' 
      c.mass_permissions.should == 'private' 
    end

    it "Blows away prior perms when 'private' is set" do 
      c.mass_permissions = 'public' 
      c.mass_permissions.should == 'public' 

      c.mass_permissions = 'private'
      c.mass_permissions.should == 'private' 
      c.rightsMetadata.permissions({group: 'public'}).should == 'none'  
    end

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
      p_coll.parent = 'neu:1' 
      p_coll.parent.should be nil 
    end

    it "Sets the parent collection, saves, and looks up to get the parent object" do 
      p_coll.parent = @saved_root.pid 
      p_coll.parent.should be nil 
      p_coll.save! 

      saved_coll = NuCollection.find(p_coll.pid) 
      saved_coll.parent.should == @saved_root  
    end
  end

  describe "Embargo Checks" do
    let(:embargoed_collection) { NuCollection.new }
    let(:no_embargo) { NuCollection.new }   
    let(:bill) { FactoryGirl.create(:bill) } 
    let(:bo) { FactoryGirl.create(:bo) } 

    before do 
      embargoed_collection.embargo_release_date = Date.tomorrow
      embargoed_collection.depositor = bill.nuid  
    end

    it "Embargoed collection is embargoed for bo" do 
      embargoed_collection.embargo_in_effect?(bo).should be true 
    end

    it "Embargoed collection is not embargoed for the depositor, bill" do 
      embargoed_collection.embargo_in_effect?(bill).should be false 
    end

    it "Embargoed collection is embargoed for the general public" do 
      embargoed_collection.embargo_in_effect?(nil).should be true 
    end

    it "Embargoless collection is not embargoed for bo" do 
      no_embargo.embargo_in_effect?(bo).should be false 
    end

    it "Embargoless collection is not embargoed for the depositor, bill" do 
      no_embargo.embargo_in_effect?(bill).should be false 
    end

    it "Embargoless collection is not embargoed for the general public" do 
      no_embargo.embargo_in_effect?(bo).should be false 
    end
  end

  after :all do 
    NuCollection.find(:all).each do |coll| 
      coll.destroy 
    end  
  end
end