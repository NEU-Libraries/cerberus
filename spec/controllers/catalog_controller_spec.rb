require 'spec_helper'

describe CatalogController do
  before :all do
    # Lazy
    x = Proc.new { |x| FactoryGirl.create(x) }

    @theses  = x.call(:theses)
    @theses2 = x.call(:theses)
    @theses3 = x.call(:theses)
    @almost_theses = NuCoreFile.create(mass_permissions: 'public',
                                       depositor: 'a@a.com',
                                       category: 'thes')

    @research  = x.call(:research)
    @research2 = x.call(:research)
    @research3 = x.call(:research)
    # Make sure search is only on category key
    @research.title = "Theses" ; @research.save!

    @presentation  = x.call(:presentation)
    @presentation1 = x.call(:presentation)
    @presentation2 = x.call(:presentation)

    @dataset  = x.call(:dataset)
    @dataset1 = x.call(:dataset)
    @dataset2 = x.call(:dataset)

    @learning_object =  x.call(:learning_object)
    @learning_object1 = x.call(:learning_object)
    @learning_object2 = x.call(:learning_object)
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

  # We no longer use these actions, and do a direct search instead.
  # These actions were causing faceting to fail...

  # describe "#GET theses" do
  #   before(:all) { category_context(:theses, 3, 'Theses and Dissertations') }
  #   it_should_behave_like 'category specific search'
  # end

  # describe "#GET research" do
  #   before(:all) { category_context(:research, 3, 'Research Publications') }
  #   it_should_behave_like 'category specific search'
  # end

  # describe "#GET presentations" do
  #   before(:all) { category_context(:presentations, 3, 'Presentations') }
  #   it_should_behave_like 'category specific search'
  # end

  # describe "#GET datasets" do
  #   before(:all) { category_context(:datasets, 3, 'Datasets') }
  #   it_should_behave_like 'category specific search'
  # end

  # describe "#GET learning_objects" do
  #   before(:all) { category_context(:learning_objects, 3, "Learning Objects") }
  #   it_should_behave_like 'category specific search'
  # end
end
