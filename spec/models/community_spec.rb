require 'spec_helper' 

describe Community do 
  
  describe "Behavior of Parent setter" do 
  end

  describe "behavior of recursions" do
    let(:root_community) { Community.new }
        
    before do
      root_community.save! 
      @root_community = Community.find(root_community.pid) 
    end

    it "responds with all descendent collections" do
      @test_collection_a = NuCollection.create(parent: @root_community.pid)
      @test_collection_b = NuCollection.create(parent: @root_community.pid)
      @test_collection_c = NuCollection.create(parent: @root_community.pid)

      @test_collection_x = NuCollection.create(parent: @test_collection_a.pid)
      @test_collection_y = NuCollection.create(parent: @test_collection_a.pid)
      @test_collection_z = NuCollection.create(parent: @test_collection_c.pid)


      root_community.all_descendent_collections.count.should == 6
    end

    it "responds with all descendent communities" do
      @test_community_a = Community.create(parent: @root_community.pid)
      @test_community_b = Community.create(parent: @root_community.pid)
      @test_community_c = Community.create(parent: @root_community.pid)

      @test_community_x = Community.create(parent: @test_community_a.pid)
      @test_community_y = Community.create(parent: @test_community_a.pid)
      @test_community_z = Community.create(parent: @test_community_c.pid)      

      root_community.all_descendent_communities.count.should == 6
    end

    it "responds with all descendent files" do
      @test_file_1 = NuCoreFile.create(title: "Core File One", parent: @test_collection_a, depositor: "nobody@nobody.com") 
      @test_file_2 = NuCoreFile.create(title: "Core File Two", parent: @test_collection_y, depositor: "nobody@nobody.com")
      @test_file_3 = NuCoreFile.create(title: "Core File Two", parent: @test_collection_z, depositor: "nobody@nobody.com")

      root_community.all_descendent_files == 3
    end

    it "deletes all collections, communities, and files pertaining to this community" do
      @root_community.recursive_delete

      Community.find(:all).length.should == 0
      NuCollection.find(:all).length.should == 0 
      NuCoreFile.find(:all).length.should == 0      
    end
  end


end