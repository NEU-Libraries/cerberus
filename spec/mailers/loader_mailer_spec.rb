require "spec_helper"
describe LoaderMailer do

  describe "load_alert" do
    before :each do
      `mysql -u "#{ENV["HANDLE_TEST_USERNAME"]}" < "#{Rails.root}"/spec/fixtures/files/handlesTEST.sql`
      @client = Mysql2::Client.new(:host => "#{ENV["HANDLE_TEST_HOST"]}", :username => "#{ENV["HANDLE_TEST_USERNAME"]}", :password => "#{ENV["HANDLE_TEST_PASSWORD"]}", :database => "#{ENV["HANDLE_TEST_DATABASE"]}")
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
      permissions = {"CoreFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:repository:staff"]}, "ImageSmallFile" => {"read"  => ["northeastern:drs:repository:staff"], "edit" => ["northeastern:drs:repository:staff"]}, "ImageLargeFile" => {"read"  => ["northeastern:drs:repository:staff"], "edit" => ["northeastern:drs:repository:staff"]}, "ImageMasterFile" => {"read"  => ["northeastern:drs:repository:staff"], "edit" => ["northeastern:drs:repository:staff"]}}
      ProcessIptcZipJob.new(@loader_name, new_file.to_s, parent, copyright, @user, permissions, @client).run
    end

    let(:mail) { LoaderMailer.load_alert }

    it "should have a subject with a correct subject" do
      expect(ActionMailer::Base.deliveries.length).to eq 1
      expect(ActionMailer::Base.deliveries.first.subject).to eq "[DRS] Load Complete"
    end

    after :each do
      @client.query("DROP DATABASE #{ENV["HANDLE_TEST_DATABASE"]};")
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
end
