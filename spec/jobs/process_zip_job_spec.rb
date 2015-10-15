require 'spec_helper'

describe ProcessIptcZipJob do
    before(:each) do
      `mysql -u "#{ENV["HANDLE_USERNAME"]}" < "#{Rails.root}"/spec/fixtures/files/handlesTEST.sql`
      @client = Mysql2::Client.new(:host => "#{ENV["HANDLE_TEST_HOST"]}", :username => "#{ENV["HANDLE_TEST_USERNAME"]}", :password => "#{ENV["HANDLE_TEST_PASSWORD"]}", :database => "#{ENV["HANDLE_TEST_DATABASE"]}")
      ActionMailer::Base.deliveries = []
      @loader_name = "College of Engineering"
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      @uniq_hsh = Digest::MD5.hexdigest("#{Rails.root}/spec/fixtures/files/jpgs.zip")[0,2]
      file_name = "#{Time.now.to_f.to_s.gsub!('.','-')}-#{@uniq_hsh}"
      new_path = tempdir.join(file_name).to_s
      @new_file = "#{new_path}.zip"
      FileUtils.cp("#{Rails.root}/spec/fixtures/files/jpgs.zip", @new_file)
      parent = FactoryGirl.create(:root_collection).pid
      copyright = "Copyright statement"
      @user = FactoryGirl.create(:admin)
      permissions = {"CoreFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:repository:staff"]}, "ImageSmallFile" => {"read"  => ["northeastern:drs:repository:staff"], "edit" => ["northeastern:drs:repository:staff"]}, "ImageLargeFile" => {"read"  => ["northeastern:drs:repository:staff"], "edit" => ["northeastern:drs:repository:staff"]}, "ImageMasterFile" => {"read"  => ["northeastern:drs:repository:staff"], "edit" => ["northeastern:drs:repository:staff"]}}
<<<<<<< HEAD
      ProcessIptcZipJob.new(@loader_name, new_file.to_s, parent, copyright, @user, permissions, @client).run
=======
      ProcessZipJob.new(@loader_name, @new_file.to_s, parent, copyright, @user, permissions, @client).run
>>>>>>> master
    end

    it 'changes loadreport length to 1' do
      Loaders::LoadReport.all.length.should == 1
    end

    it 'removes zip file from tmp dir' do
      File.exist?("#{@new_file}").should be false
    end

    it 'triggers image report job' do
      Loaders::ImageReport.all.length.should == 3
    end

    it 'creates two core files' do
      CoreFile.all.length.should == 3
    end

    it 'sets correct number of success, fail, total number counts' do
      lr = Loaders::LoadReport.all.first
      lr.number_of_files.should == 3
      lr.success_count.should == 2
      lr.modified_count.should == 1
      lr.fail_count.should == 0
    end

    it 'sends email correctly' do
      expect(ActionMailer::Base.deliveries.length).to eq 1
      expect(ActionMailer::Base.deliveries.first.subject).to eq "[DRS] Load Complete"
    end

    after(:each) do
      @client.query("DROP DATABASE #{ENV["HANDLE_TEST_DATABASE"]};")
      @user.destroy if @user
      Loaders::LoadReport.all.each do |lr|
        lr.destroy
      end
      Loaders::ImageReport.all.each do |ir|
        ir.destroy
      end
      ActiveFedora::Base.destroy_all
    end

end
