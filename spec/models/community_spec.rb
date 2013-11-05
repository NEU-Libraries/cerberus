require 'spec_helper' 

describe Community do 
  
  describe "Behavior of Parent setter" do 
  end

  describe "behavior of decendent getter" do
    let(:root_community) { Community.new }
    
    #all_descendent_collections

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

  end


end