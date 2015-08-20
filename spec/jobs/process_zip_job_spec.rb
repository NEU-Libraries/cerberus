require 'spec_helper'
include HandleHelper

describe ProcessZipJob, unless: $in_travis do
    before(:all) do
      @loader_name = "College of Engineering"
      tempdir = Rails.root.join("tmp")
      @uniq_hsh = Digest::MD5.hexdigest("#{Rails.root}/spec/fixtures/files/jpgs.zip")[0,2]
      file_name = "#{Time.now.to_i.to_s}-#{@uniq_hsh}"
      new_path = tempdir.join(file_name).to_s
      new_file = "#{new_path}.zip"
      FileUtils.cp("#{Rails.root}/spec/fixtures/files/jpgs.zip", new_file)
      parent = FactoryGirl.create(:root_collection).pid
      copyright = "Copyright statement"
      @user = FactoryGirl.create(:user)
      permissions = {"CoreFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:repository:staff"]}, "ImageThumbnailFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:repository:staff"]}, "ImageSmallFile" => {"read"  => ["northeastern:drs:repository:staff"], "edit" => ["northeastern:drs:repository:staff"]}, "ImageLargeFile" => {"read"  => ["northeastern:drs:repository:staff"], "edit" => ["northeastern:drs:repository:staff"]}, "ImageMasterFile" => {"read"  => ["northeastern:drs:repository:staff"], "edit" => ["northeastern:drs:repository:staff"]}}
      ProcessZipJob.new(@loader_name, new_file.to_s, parent, copyright, @user, permissions).run
    end

    it 'changes loadreport length to 1' do
      Loaders::LoadReport.all.length.should == 1
    end

    it 'removes zip file from tmp dir' do
      File.exist?("#{Rails.root}/tmp/#{Time.now.to_i.to_s}-#{@uniq_hsh}.zip").should be false
    end

    it 'triggers image report job' do
      Loaders::ImageReport.all.length.should == 2
    end

    it 'creates two core files' do
      CoreFile.all.length.should == 2
    end

    it 'sets correct number of success, fail, total number counts' do
      lr = Loaders::LoadReport.all.first
      lr.number_of_files.should == 2
      lr.success_count.should == 2
      lr.fail_count.should == 0
    end

    after(:all) do
      @user.destroy if @user
      Loaders::LoadReport.all.each do |lr|
        lr.destroy
      end
      Loaders::ImageReport.all.each do |ir|
        ir.destroy
      end
      CoreFile.all.each do |c|
        c.destroy
      end
    end

end
