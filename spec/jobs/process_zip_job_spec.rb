require 'spec_helper'
describe ProcessZipJob do
    before(:all) do
      # create brooks as 'current_user'
      # cp jpgs.zip to tmp dir
      # gets parent collection pid
      # run process zip job like #Cerberus::Application::Queue.push(ProcessZipJob.new(@loader_name, new_file.to_s, parent, copyright, current_user))
    end

    it 'unzips zip file and creates dir' do
      #tmp location should have dir with name of zip file
    end

    it 'changes loadreport length to 1' do
      #should create load report
      #Loaders::LoadReport.all.length should == 1
    end

    it 'removes zip file from tmp dir' do
      #should not have zipfile in tmpdir
    end

    it 'triggers image report job' do
      #is this something to test?
    end

    after(:all) do
      # deletes brooks
      # clears out load reports and image reports
    end

end
