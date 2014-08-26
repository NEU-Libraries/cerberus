require 'spec_helper'

describe CatalogController do
  describe "GET #index" do
    describe "scoped queries" do
      before :all do
        @root = FactoryGirl.create(:root_collection)
        @col1 = FactoryGirl.create(:valid_not_embargoed)
        @col2 = FactoryGirl.create(:valid_not_embargoed)
        @col3 = FactoryGirl.create(:valid_not_embargoed)
        @col4 = FactoryGirl.create(:valid_not_embargoed)
        @col5 = FactoryGirl.create(:valid_not_embargoed)

        @core1 = FactoryGirl.create(:bills_complete_file)
        @core2 = FactoryGirl.create(:bills_complete_file)
        @core3 = FactoryGirl.create(:bills_complete_file)

        # Descendent objects of @col1
        @col1.parent = @root.pid
        @col2.parent = @col1.pid
        @col3.parent = @col1.pid
        @col4.parent = @col3.pid
        @col4.title = "Find me"

        @core1.mass_permissions = "public"
        @core1.title = "Find me"
        @core1.parent = @col4

        # Items that shouldn't show up
        @core2.title = "Find me"
        @core2.mass_permissions = "public"
        @core2.parent = @col5

        @core3.title = "Find me"
        @core3.mass_permissions = "private" # shouldn't show for unauthed user
        @core3.parent = @col2

        [@col1, @col2, @col3, @col4, @col5, @core1, @core2, @core3].map { |x| x.save! }
      end


      it "return only accessible records in the right graph subsection" do
        get :index, {id: @col1.pid, scope: @col1.pid, q: "Find me"}

        # Finds only the public file in the queried subset of the graph
        doc_list = assigns[:document_list]
        doc_list.length.should == 2
        doc_list.map { |x| x.pid}.should =~ [@core1.pid, @col4.pid]
      end

      after :all do
        Collection.destroy_all
        NuCoreFile.destroy_all
      end
    end
  end
end
