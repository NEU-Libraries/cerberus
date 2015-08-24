require "spec_helper"
describe LoaderMailer do

  describe "load_alert" do
    before :each do
      #FactoryGirl.create_list(:marcom_load)
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

    let(:mail) { LoaderMailer.load_alert }

    it "should have a subject with a correct subject" do
      expect(ActionMailer::Base.deliveries.length).to eq 1
      expect(ActionMailer::Base.deliveries.first.subject).to eq "[DRS] Load Complete"
    end

  end
end
