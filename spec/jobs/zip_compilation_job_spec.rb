require 'spec_helper'

describe ZipCompilationJob do

  # Build our sample compilation for testing
  before(:all) do
    @user        = FactoryGirl.create(:bill)
    @image       = FactoryGirl.create(:image_master_file)
    @pdf         = FactoryGirl.create(:pdf_file)
    @compilation = FactoryGirl.create(:bills_compilation)
    @zip_dir     = Rails.root.join("tmp", @compilation.pid)
  end

  describe "zipping a compilation" do

    let(:archive) { Dir.glob("#{@zip_dir}/**").first }

    before(:all) do
      @compilation.add_entry(@image.core_record.pid)
      @compilation.add_entry(@pdf.core_record.pid)
      ZipCompilationJob.new(@user, @compilation).run
      @dir_name = ZipCompilationJob.new(@user, @compilation).run
    end

    # This is just a sanity check
    # Circumstances necessitated it once, felt I should leave it in
    it "ensures that the user is only downloading objects they can read" do
      @user.can?(:read, @image).should be true
      @user.can?(:read, @pdf).should be true
      @user.can?(:read, @image.core_record).should be true
      @user.can?(:read, @pdf.core_record).should be true
    end

    it "spins up the requisite directory" do
      File.directory?(@zip_dir).should be true
    end

    it "adds the zipfile and removes the old zipfile" do
      Dir.glob("#{@zip_dir}/**").length.should be 1
    end

    it "creates a zipfile with the right files in it" do
      Zip::Archive.open(archive) do |ar|
        t = @compilation.title
        coll = ["#{t}/#{@image.title}", "#{t}/#{@pdf.title}"]
        [ar.get_name(0), ar.get_name(1)].should =~ coll
      end
    end
  end

  after(:all) do
    User.destroy_all
    NuCoreFile.all.map { |x| x.destroy }
    Compilation.all.map { |c| c.destroy }

    if File.directory? Rails.root.join("tmp", @compilation.pid)
      FileUtils.remove_dir Rails.root.join("tmp", @compilation.pid)
    end
  end
end
