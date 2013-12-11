require 'spec_helper'

describe CatalogController do 
  before :all do 
    @theses  = FactoryGirl.create(:theses) 
    @theses2 = FactoryGirl.create(:theses) 
    @theses3 = FactoryGirl.create(:theses)
    @almost_theses = NuCoreFile.create(mass_permissions: 'public', 
                                       depositor: 'a@a.com', 
                                       category: 'thes')  

    @research  = FactoryGirl.create(:research) 
    @research2 = FactoryGirl.create(:research) 
    @research3 = FactoryGirl.create(:research)
    # Make sure search is only on category key
    @research.title = "Theses" ; @research.save! 

    @presentation  = FactoryGirl.create(:presentation) 
    @presentation1 = FactoryGirl.create(:presentation) 
    @presentation2 = FactoryGirl.create(:presentation)   
  end

  after :all do 
    @theses.destroy ; @theses2.destroy ; @theses3.destroy 
    @research.destroy ; @research2.destroy ; @research3.destroy
  end

  def category_context(action, count, category) 
    @action = action 
    @count = count 
    @category = category 
  end

  shared_examples_for "category specific search" do 
    let(:response) { assigns(:response)['response'] } 
    before(:each)  { get @action } 

    it "returns the correct number of results" do 
      response['numFound'].should == @count 
    end

    it "returns docs of appropriate category" do 
      cat = 'drs_category_ssim' 
      response['docs'][0][cat].should == [@category]
      response['docs'][1][cat].should == [@category] 
      response['docs'][2][cat].should == [@category]
    end
  end

  describe "#GET theses" do 
    before(:all) { category_context(:theses, 3, 'Theses and Dissertations') } 
    it_should_behave_like 'category specific search' 
  end

  describe "#GET research" do 
    before(:all) { category_context(:research, 3, 'Research Publications') } 
    it_should_behave_like 'category specific search' 
  end

  describe "#GET presentations" do 
    before(:all) { category_context(:presentations, 3, 'Presentations')}
    it_should_behave_like 'category specific search' 
  end
end