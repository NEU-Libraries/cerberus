require 'spec_helper'

describe ProcessZipJob do
    before(:each) do
      `mysql -u "#{ENV["HANDLE_USERNAME"]}" < "#{Rails.root}"/spec/fixtures/files/handlesTEST.sql`
      @client = Mysql2::Client.new(:host => "#{ENV["HANDLE_HOST"]}", :username => "#{ENV["HANDLE_USERNAME"]}", :password => "#{ENV["HANDLE_PASSWORD"]}", :database => "#{ENV["HANDLE_DATABASE"]}")
      ActionMailer::Base.deliveries = []
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

    it 'sends email correctly' do
      expect(ActionMailer::Base.deliveries.length).to eq 1
      expect(ActionMailer::Base.deliveries.first.subject).to eq "[DRS] Load Complete"
    end

    after(:each) do
      @client.query("TRUNCATE TABLE handles_test.handles;")
      @user.destroy if @user
      Loaders::LoadReport.all.each do |lr|
        lr.destroy
      end
      Loaders::ImageReport.all.each do |ir|
        ir.destroy
      end
      CoreFile.all.map { |x| x.destroy }
    end

end
