require 'spec_helper'

describe ProcessMultipageZipJob do
  before(:all) do
    `mysql -u "#{ENV["HANDLE_USERNAME"]}" < "#{Rails.root}"/spec/fixtures/files/handlesTEST.sql`
    @client = Mysql2::Client.new(:host => "#{ENV["HANDLE_TEST_HOST"]}", :username => "#{ENV["HANDLE_TEST_USERNAME"]}", :password => "#{ENV["HANDLE_TEST_PASSWORD"]}", :database => "#{ENV["HANDLE_TEST_DATABASE"]}")
    @loader_name = "Multipage"
    @user = FactoryGirl.create(:admin)
  end

  after(:all) do
    @client.query("DROP DATABASE #{ENV["HANDLE_TEST_DATABASE"]};")
    @user.destroy if @user
  end

  shared_examples_for "success" do
    it 'creates a load report' do
      Loaders::LoadReport.all.length.should == 1
    end

    it 'removes zip file from tmp dir' do
      File.exist?("#{@new_file}").should be false
    end

    it 'creates image reports' do
      Loaders::ImageReport.all.length.should == 1
    end

    it 'creates one core file' do
      CoreFile.count.should == 1
    end

    it "sets core_file depositor" do
      cf = CoreFile.first
      cf.depositor.should == @user.nuid
    end

    it "sets core_file parent" do
      cf = CoreFile.first
      cf.parent.should == @parent
      cf.properties.parent_id = @parent.pid
    end

    it "creates handle" do
      cf = CoreFile.first
      cf.mods.identifier.should_not == nil
      cf.mods.identifier.type.should == ["hdl"]
    end

    it 'sets correct number of success, fail, total number counts' do
      lr = Loaders::LoadReport.all.first
      lr.number_of_files.should == 1
      lr.success_count.should == 1
      lr.fail_count.should == 0
    end

    it "sets permissions" do
      cf = CoreFile.first
      cf.permissions.should == [{:type=>"group", :access=>"read", :name=>"public"}, {:type=>"group", :access=>"edit", :name=>"northeastern:drs:repository:staff"}, {:type=>"user", :access=>"edit", :name=>"000000000"}]
    end
  end

  shared_examples_for "failure" do
    it 'creates a load report' do
      Loaders::LoadReport.all.length.should == 1
      lr = Loaders::LoadReport.all.first
      lr.number_of_files.should == 1
      lr.fail_count.should == 1
    end

    it 'does not create a core file' do
      CoreFile.count.should == 0
    end
  end

  context "multipage object" do
    before(:all) do
      @parent = FactoryGirl.create(:root_collection)
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      @uniq_hsh = Digest::MD5.hexdigest("#{Rails.root}/spec/fixtures/files/multipage.zip")[0,2]
      file_name = "#{Time.now.to_f.to_s.gsub!('.','-')}-#{@uniq_hsh}"
      new_path = tempdir.join(file_name).to_s
      @new_file = "#{new_path}.zip"
      FileUtils.cp("#{Rails.root}/spec/fixtures/files/multipage.zip", @new_file)
      copyright = "Copyright statement"
      @permissions = {"CoreFile" => {"read"  => ["public"], "edit" => ["northeastern:drs:repository:staff"]}}
      ProcessMultipageZipJob.new(@loader_name, @new_file.to_s, @parent.pid, copyright, @user, @permissions, @client).run
    end

    it_should_behave_like "success"

    it "sets core_file title" do
      cf = CoreFile.first
      cf.title.should == "Youngs Gap Casino, Parksville, N.Y."
    end

    it 'creates two page file objects attached' do
      cf = CoreFile.first
      cf.page_objects.count.should == 2
    end

    it "sets original_filename" do
      cf = CoreFile.first
      cf.properties.original_filename.should == ["bdr_43888.mods.xml"]
      cf.label.should == "bdr_43888.mods.xml"
    end

    after :all do
      Loaders::LoadReport.destroy_all
      Loaders::ImageReport.destroy_all
      ActiveFedora::Base.destroy_all
    end
  end

  context "single object" do
    before(:all) do
      @parent = FactoryGirl.create(:root_collection)
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      @uniq_hsh = Digest::MD5.hexdigest("#{Rails.root}/spec/fixtures/files/multipage-notmulti.zip")[0,2]
      file_name = "#{Time.now.to_f.to_s.gsub!('.','-')}-#{@uniq_hsh}"
      new_path = tempdir.join(file_name).to_s
      @new_file = "#{new_path}.zip"
      FileUtils.cp("#{Rails.root}/spec/fixtures/files/multipage-notmulti.zip", @new_file)
      copyright = "Copyright statement"
      @permissions = {"CoreFile" => {"read"  => ["public"], "edit" => ["northeastern:drs:repository:staff"]}}
      ProcessMultipageZipJob.new(@loader_name, @new_file.to_s, @parent.pid, copyright, @user, @permissions, @client).run
    end

    it_should_behave_like "success"

    it "sets core_file title" do
      cf = CoreFile.first
      cf.title.should == "Adler's Bungalow Colony, Greenfield Park, N.Y., pool and cottages"
    end

    it "sets canonical_object" do
      cf = CoreFile.first
      cf.canonical_object.class.should == ImageMasterFile
    end

    it "sets original_filename" do
      cf = CoreFile.first
      cf.properties.original_filename.should == ["bdr.mods.xml"]
      cf.label.should == "bdr.mods.xml"
    end

    it "does not create page_objects" do
      cf = CoreFile.first
      cf.page_objects.count.should == 0
      PageFile.count.should == 0
    end

    after :all do
      Loaders::LoadReport.destroy_all
      Loaders::ImageReport.destroy_all
      ActiveFedora::Base.destroy_all
    end
  end

  context "fails if invalid mods" do
    before(:all) do
      @parent = FactoryGirl.create(:root_collection)
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      @uniq_hsh = Digest::MD5.hexdigest("#{Rails.root}/spec/fixtures/files/multipage-invalid-mods.zip")[0,2]
      file_name = "#{Time.now.to_f.to_s.gsub!('.','-')}-#{@uniq_hsh}"
      new_path = tempdir.join(file_name).to_s
      @new_file = "#{new_path}.zip"
      FileUtils.cp("#{Rails.root}/spec/fixtures/files/multipage-invalid-mods.zip", @new_file)
      copyright = "Copyright statement"
      @permissions = {"CoreFile" => {"read"  => ["public"], "edit" => ["northeastern:drs:repository:staff"]}}
      ProcessMultipageZipJob.new(@loader_name, @new_file.to_s, @parent.pid, copyright, @user, @permissions, @client).run
    end

    it_should_behave_like "failure"

    it 'creates image report' do
      Loaders::ImageReport.all.length.should == 1
      rep = Loaders::ImageReport.first
      rep.exception.should == "Invalid MODS"
    end

    after :all do
      Loaders::LoadReport.destroy_all
      Loaders::ImageReport.destroy_all
      ActiveFedora::Base.destroy_all
    end
  end

  context  "fails if no mods provided" do
    before(:all) do
      @parent = FactoryGirl.create(:root_collection)
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      @uniq_hsh = Digest::MD5.hexdigest("#{Rails.root}/spec/fixtures/files/multipage-no-mods.zip")[0,2]
      file_name = "#{Time.now.to_f.to_s.gsub!('.','-')}-#{@uniq_hsh}"
      new_path = tempdir.join(file_name).to_s
      @new_file = "#{new_path}.zip"
      FileUtils.cp("#{Rails.root}/spec/fixtures/files/multipage-no-mods.zip", @new_file)
      copyright = "Copyright statement"
      permissions = {"CoreFile" => {"read"  => ["public"], "edit" => ["northeastern:drs:repository:staff"]}}
      ProcessMultipageZipJob.new(@loader_name, @new_file.to_s, @parent.pid, copyright, @user, permissions, @client).run
    end

    it_should_behave_like "failure"

    it 'creates image report' do
      Loaders::ImageReport.all.length.should == 1
      rep = Loaders::ImageReport.first
      rep.exception.should == "Can't load MODS XML"
    end

    after :all do
      Loaders::LoadReport.destroy_all
      Loaders::ImageReport.destroy_all
      ActiveFedora::Base.destroy_all
    end
  end

  context "bad row sequence" do
    before(:all) do
      @parent = FactoryGirl.create(:root_collection)
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      @uniq_hsh = Digest::MD5.hexdigest("#{Rails.root}/spec/fixtures/files/multipage-bad-sequence.zip")[0,2]
      file_name = "#{Time.now.to_f.to_s.gsub!('.','-')}-#{@uniq_hsh}"
      new_path = tempdir.join(file_name).to_s
      @new_file = "#{new_path}.zip"
      FileUtils.cp("#{Rails.root}/spec/fixtures/files/multipage-bad-sequence.zip", @new_file)
      copyright = "Copyright statement"
      permissions = {"CoreFile" => {"read"  => ["public"], "edit" => ["northeastern:drs:repository:staff"]}}
      ProcessMultipageZipJob.new(@loader_name, @new_file.to_s, @parent.pid, copyright, @user, permissions, @client).run
    end

    it_should_behave_like "failure"

    it 'creates image report' do
      Loaders::ImageReport.all.length.should == 1
      rep = Loaders::ImageReport.first
      rep.exception.should == "Row is out of order - row num 3 seq_num 1"
    end

    after :all do
      Loaders::LoadReport.destroy_all
      Loaders::ImageReport.destroy_all
      ActiveFedora::Base.destroy_all
    end
  end
end
