require 'spec_helper' 

describe Community do 
  
  describe "Behavior of Parent setter" do 
  end

  describe "Get all child collections" do
    let(:root_community) { Community.new }
    let(:test_collection_a) { NuCollection.new }
    let(:test_collection_b) { NuCollection.new }
    let(:test_collection_c) { NuCollection.new }
    
    #all_descendent_collections

    before do
      root_community.save! 
      @root_community = NuCollection.find(root_community.pid) 
    end
  end


end