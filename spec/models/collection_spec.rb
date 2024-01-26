require 'spec_helper'

describe Collection do

  let(:collection) { Collection.new }

  describe "Custom setters and getters" do
    let(:c) { Collection.new }

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
    let(:p_coll) { Collection.new }
    let(:root) { Collection.new }

    before do
      root.save!
      @saved_root = Collection.find(root.pid)
    end

    it "Sets the parent collection, but receives nil" do
      p_coll.parent = @saved_root.pid
      p_coll.parent.should == @saved_root
    end
  end

  describe "User parent" do
    before do
      Employee.destroy_all
    end

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

      @root = Collection.create(title: "Root")
      @child_one = Collection.create(title: "Child One", parent: @root)
      @c1_gf = CoreFile.create(title: "Core File One", parent: @child_one, depositor: "nobody@nobody.com")
      @c2_gf = CoreFile.create(title: "Core File Two", parent: @child_one, depositor: "nobody@nobody.com")
      @child_two = Collection.create(title: "Child Two", parent: @root)
      @grandchild = Collection.create(title: "Grandchild", parent: @child_two)
      @great_grandchild = Collection.create(title: "Great Grandchild", parent: @grandchild)
      @gg_gf = CoreFile.create(title: "GG CF", parent: @great_grandchild, depositor: "nobody@nobody.com")
      @pids = [ @root.pid, @child_one.pid, @c1_gf.pid, @c2_gf.pid, @child_two.pid, @grandchild.pid, @great_grandchild.pid,
                @gg_gf.pid]
    end

    it "deletes the item its called on and all descendent files and collections." do
      @root.recursive_delete
      Collection.find(:all).length.should == 0
      CoreFile.find(:all).length.should   == 0
    end
  end

  describe 'tombstone collection' do
    shared_examples_for "successful tombstone collection" do
      it "sets properties.tombstoned to true" do
        @child_one.properties.tombstoned should = 'true'
      end

      it "sets solr doc tombstoned_ssi to true" do
        @solr["tombstoned_ssi"].should == 'true'
      end

      it "sets tombstoned? to true" do
        @child_one.tombstoned?.should be true
      end

      it "tombstones corefile children" do
        doc =  SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{@child_one.pid}\"").first)
        doc.child_files.each do |child|
          child = CoreFile.find("#{child.pid}")
          child.tombstoned?.should be true
        end
      end

      it "tombstones collection children" do
        @child_two.tombstone
        @child_two.save!
        @child_two.child_collections do |col_child|
          col_child.tombstoned?.should be true
        end
      end

      it "tombstones corefile great grandchild" do
        @child_two.tombstone
        @child_two.save!
        gg = CoreFile.find("#{@gg_gf.pid}")
        gg.tombstoned?.should be true
      end

      it "tombstones collection great grandchild" do
        @child_two.tombstone
        @child_two.save!
        gg = Collection.find("#{@great_grandchild.pid}")
        gg.tombstoned?.should be true
      end

      after(:each) do
        ActiveFedora::Base.find(:all).each do |file|
          file.destroy
        end
      end
    end

    context 'with tombstone reason' do
      before(:each) do
        ActiveFedora::Base.find(:all).each do |file|
          file.destroy
        end

        @root = Collection.create(title: "Root")
        @child_one = Collection.create(title: "Child One", parent: @root)
        @c1_gf = CoreFile.create(title: "Core File One", parent: @child_one, depositor: "nobody@nobody.com")
        @child_two = Collection.create(title: "Child Two", parent: @root)
        @grandchild = Collection.create(title: "Grandchild", parent: @child_two)
        #these two
        @great_grandchild = Collection.create(title: "Great Grandchild", parent: @grandchild)
        @gg_gf = CoreFile.create(title: "GG CF", parent: @great_grandchild, depositor: "nobody@nobody.com")
        @child_one.tombstone("Removed at the request of Northeastern University")
        @child_one.save!
        @solr = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{@child_one.pid}\"").first)
      end

      it "has tombstone message" do
        @solr = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{@child_one.pid}\"").first)
        @child_one.tombstone_reason.should == "Removed at the request of Northeastern University"
        @solr.tombstone_reason.should == "Removed at the request of Northeastern University"
      end

      it "has mods accessCondition" do
        @child_one.mods.access_condition.should == ["Removed at the request of Northeastern University"]
      end

      it "has correct mods accessCondition type" do
        @child_one.mods.access_condition(0).type.should == ["suppressed"]
      end

      it "sets corefile children tombstone message" do
        doc =  SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{@child_one.pid}\"").first)
        doc.child_files.each do |child|
          child = CoreFile.find("#{child.pid}")
          child.tombstone_reason.should == "Removed at the request of Northeastern University"
          child.mods.access_condition.should == ["Removed at the request of Northeastern University"]
          child.mods.access_condition(0).type.should == ["suppressed"]
          child_solr = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{child.pid}\"").first)
          child_solr.tombstone_reason.should == "Removed at the request of Northeastern University"
        end
      end

      it "sets collection children tombstone message" do
        @child_two.tombstone("Removed at the request of Northeastern University")
        @child_two.save!
        @child_two.child_collections do |col_child|
          col_child.tombstone_reason.should == "Removed at the request of Northeastern University"
          col_child.mods.access_condition.should == ["Removed at the request of Northeastern University"]
          col_child.mods.access_condition(0).type.should == ["suppressed"]
          col_child_solr = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{col_child.pid}\"").first)
          col_child_solr.tombstone_reason.should == "Removed at the request of Northeastern University"
        end
      end

      it "sets corefile great grandchild tombstone message" do
        @child_two.tombstone("Removed at the request of Northeastern University")
        @child_two.save!
        gg = CoreFile.find("#{@gg_gf.pid}")
        gg.tombstone_reason.should == "Removed at the request of Northeastern University"
        gg.mods.access_condition.should == ["Removed at the request of Northeastern University"]
        gg.mods.access_condition(0).type.should == ["suppressed"]
        gg_solr = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{gg.pid}\"").first)
        gg_solr.tombstone_reason.should == "Removed at the request of Northeastern University"
      end

      it "sets collection great grandchild tombstone message" do
        @child_two.tombstone("Removed at the request of Northeastern University")
        @child_two.save!
        gg = Collection.find("#{@great_grandchild.pid}")
        gg.tombstone_reason.should == "Removed at the request of Northeastern University"
        gg.mods.access_condition.should == ["Removed at the request of Northeastern University"]
        gg.mods.access_condition(0).type.should == ["suppressed"]
        gg_solr = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{gg.pid}\"").first)
        gg_solr.tombstone_reason.should == "Removed at the request of Northeastern University"
      end

      it_should_behave_like 'successful tombstone collection'
    end

    context 'without tombstone reason' do
      before(:each) do
        ActiveFedora::Base.find(:all).each do |file|
          file.destroy
        end

        @root = Collection.create(title: "Root")
        @child_one = Collection.create(title: "Child One", parent: @root)
        @c1_gf = CoreFile.create(title: "Core File One", parent: @child_one, depositor: "nobody@nobody.com")
        @child_two = Collection.create(title: "Child Two", parent: @root)
        @grandchild = Collection.create(title: "Grandchild", parent: @child_two)
        @great_grandchild = Collection.create(title: "Great Grandchild", parent: @grandchild)
        @gg_gf = CoreFile.create(title: "GG CF", parent: @great_grandchild, depositor: "nobody@nobody.com")
        @child_one.tombstone
        @child_one.save!
        @solr = @child_one.to_solr
      end

      it_should_behave_like 'successful tombstone collection'
    end
  end

  describe 'revive collection' do
    shared_examples_for 'successful revive collection' do
      it "has no mods accessCondition" do
        @child_one.revive
        @child_one.mods.access_condition.should == []
      end

      it "has no tombstone reason" do
        @child_one.revive
        @child_one.tombstone_reason.should == []
      end

      it "sets properties.tombstoned to empty" do
        @child_one.revive
        @child_one.properties.tombstoned should = ''
      end

      it "sets solr doc tombstoned_ssi to empty" do
        @child_one.revive
        @child_one.save!
        @solr = @child_one.to_solr
        @solr["tombstoned_ssi"].should be nil
      end

      it "sets tombstoned? to false" do
        @child_one.revive
        @child_one.tombstoned?.should be false
      end

      it "returns false if parent is tombstoned" do
        @child_two.tombstone
        @child_two.save!
        @grandchild.revive.should be false
      end

      it "revives corefile children" do
        @child_one.revive
        doc =  SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{@child_one.pid}\"").first)
        doc.child_files.each do |child|
          child = CoreFile.find("#{child.pid}")
          child.mods.access_condition.should == []
          child.tombstone_reason.should == []
        end
      end

      it "revives collection children and grandchildren and corefile great grandchildren" do
        @child_two.revive
        @child_two.save!
        gg = CoreFile.find("#{@gg_gf.pid}")
        cfs = ActiveFedora::SolrService.query("parent_id_tesim:\"#{@child_two.pid}\"")
        cfs.each do |cf|
          if cf['active_fedora_model_ssi'] == 'CoreFile'
            child = CoreFile.find(cf['id'])
            child.tombstoned?.should be false
            child.mods.access_condition.should == []
            child.tombstone_reason.should == []
          elsif cf['active_fedora_model_ssi'] == 'Collection'
            col_child = Collection.find(cf['id'])
            col_child.tombstoned?.should be false
            col_child.mods.access_condition.should == []
            col_child.tombstone_reason.should == []
          end
        end
      end

      after :all do
        ActiveFedora::Base.find(:all).each do |file|
          file.destroy
        end
      end
    end

    context 'without tombstone reason' do
      before(:each) do
        @root = Collection.create(title: "Root")
        @child_one = Collection.create(title: "Child One", parent: @root)
        @c1_gf = CoreFile.create(title: "Core File One", parent: @child_one, depositor: "nobody@nobody.com")
        @child_two = Collection.create(title: "Child Two", parent: @root)
        @grandchild = Collection.create(title: "Grandchild", parent: @child_two)
        @great_grandchild = Collection.create(title: "Great Grandchild", parent: @grandchild)
        @gg_gf = CoreFile.create(title: "GG CF", parent: @great_grandchild, depositor: "nobody@nobody.com")
        @child_one.tombstone
        @child_one.save!
        @solr =  @child_one.to_solr
        @child_two.tombstone
        @child_two.save!
      end

      it_should_behave_like "successful revive collection"
    end

    context 'with tombstone reason' do
      before(:each) do
        @root = Collection.create(title: "Root")
        @child_one = Collection.create(title: "Child One", parent: @root)
        @c1_gf = CoreFile.create(title: "Core File One", parent: @child_one, depositor: "nobody@nobody.com")
        @child_two = Collection.create(title: "Child Two", parent: @root)
        @grandchild = Collection.create(title: "Grandchild", parent: @child_two)
        @great_grandchild = Collection.create(title: "Great Grandchild", parent: @grandchild)
        @gg_gf = CoreFile.create(title: "GG CF", parent: @great_grandchild, depositor: "nobody@nobody.com")
        @child_one.tombstone("Removed at the request of Northeastern University")
        @child_one.save!
        @solr =  @child_one.to_solr
        @child_two.tombstone("Removed at the request of Northeastern University")
        @child_two.save!
      end

      it_should_behave_like "successful revive collection"
    end
  end

  after :all do
    ActiveFedora::Base.find(:all).each do |file|
      file.destroy
    end
  end

end