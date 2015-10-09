require 'spec_helper'
include HandleHelper

describe ImageProcessingJob do
  def context(o_path)
    `mysql -u "#{ENV["HANDLE_TEST_USERNAME"]}" < "#{Rails.root}"/spec/fixtures/files/handlesTEST.sql`
    @client = Mysql2::Client.new(:host => "#{ENV["HANDLE_TEST_HOST"]}", :username => "#{ENV["HANDLE_TEST_USERNAME"]}", :password => "#{ENV["HANDLE_TEST_PASSWORD"]}", :database => "#{ENV["HANDLE_TEST_DATABASE"]}")
    @collection = FactoryGirl.create(:root_collection)
    @file_name = File.basename(o_path)
    FileUtils.cp(o_path, "#{Rails.application.config.tmp_path}/#{@file_name}")
    @uniq_hsh = Digest::MD5.hexdigest("#{File.basename(o_path)}")[0,2]
    @fpath = "#{Rails.application.config.tmp_path}/#{Time.now.to_f.to_s.gsub!('.','-')}-#{@uniq_hsh}"
    File.rename("#{Rails.application.config.tmp_path}/#{@file_name}", "#{@fpath}") # Names file time and hash string
    @parent = @collection.pid
    @copyright = "Test Copyright Statement"
    @user = FactoryGirl.create(:admin)
    @loader_name = "Marketing and Communications"
    @report_id = Loaders::LoadReport.create_from_strings(@user, 0, @loader_name, @parent)
    @load_report = Loaders::LoadReport.find(@report_id)
    @permissions = {"CoreFile" => {"read"  => ["northeastern:drs:all"], "edit" => ["northeastern:drs:repository:corefile"]}, "ImageSmallFile" => {"read"  => ["northeastern:drs:repository:test"], "edit" => ["northeastern:drs:repository:small"]}, "ImageLargeFile" => {"read"  => ["northeastern:drs:repository:test"], "edit" => ["northeastern:drs:repository:large"]}, "ImageMasterFile" => {"read"  => ["northeastern:drs:repository:test"], "edit" => ["northeastern:drs:repository:master"]}}
    ImageProcessingJob.new(@fpath, @file_name, @parent, @copyright, @load_report.id, @permissions, @client).run
    @images = Loaders::ImageReport.where(load_report_id:"#{@report_id}").find_all
  end

  def clear_context
    @client.query("DROP DATABASE #{ENV["HANDLE_TEST_DATABASE"]};")
    CoreFile.all.map { |x| x.destroy }
    @load_report.destroy if @load_report
    @user.destroy if @user
    Loaders::ImageReport.all.each do |ir|
      ir.destroy
    end
  end


  describe "Image creation" do


    shared_examples_for "successful uploads" do
      it 'creates core file' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.should == CoreFile.find("#{@images.first.pid}")
      end

      it 'sets core_file.depositor to 000000000' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.depositor.should == '000000000'
      end

      it 'sets correct parent' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.parent.should == Collection.find("#{@parent}") #for marcom collection
      end

      it 'be tagged as in_progress' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.in_progress_for_user?(@user)
      end

      it 'sets title to iptc headline' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.title.should == "Blizzard Juno"
      end

      it 'sets mods classification to iptc category + supp category' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.mods.classification.should == ["campus life -- students -- cargill hall"]
      end

      it 'sets mods personal name and role to iptc byline' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.creators.should == ["Maria Amasanti"]
        @core_file.mods.personal_name.role.role_term.should == ["Photographer"]
      end

      it 'sets description to iptc description' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.description.should == "January 27, 2015 - A Northeastern University student fights the wind during a blizzard. "
      end

      it 'sets publisher to iptc source' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.mods.origin_info.publisher.should == ["Northeastern University"]
      end

      it 'sets date and copyright date to iptc date time original' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.mods.origin_info.copyright.should == ["2015-01-27"]
        @core_file.date.should == "2015-01-27"
      end

      it 'sets keywords to iptc keywords' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.keywords.should == ["blizzard", "juno", "campus", "campus life"]
      end

      it 'sets city to iptc city' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.mods.origin_info.place.city_term.should == ["Boston"]
      end

      it 'sets state to iptc state' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.mods.origin_info.place.state_term.should == ["mau"]
      end

      it 'sets static values' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.mods.genre.should == ["photographs"]
        @core_file.mods.genre.authority.should == ["aat"]
        @core_file.mods.physical_description.digital_origin.should == ["born digital"]
        @core_file.mods.physical_description.form.should == ["electronic"]
        @core_file.mods.physical_description.form.authority.should == ["marcform"]
        @core_file.mods.physical_description.extent.should == ["1 photograph"]
        @core_file.mods.access_condition.should == ["Test Copyright Statement"]
        @core_file.mods.access_condition.type.should == ["use and reproduction"]
      end

      it 'creates success report' do
        @images.count.should == 1
      end

      it 'creates handle' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.identifier.should == retrieve_handle(@core_file.persistent_url, @client)
        @core_file.mods.identifier.type.should == ["handle"]
        @core_file.mods.identifier.display_label.should == ["Permanent URL"]
      end

      it 'sets correct permissions for core_files' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.permissions.should == [{:type=>"group", :access=>"read", :name=>"northeastern:drs:all"}, {:type=>"group", :access=>"edit", :name=>"northeastern:drs:repository:corefile"}, {:type=>"user", :access=>"edit", :name=>"000000000"}]
      end

    end

    shared_examples_for "failed uploads" do
      it 'creates error report if not ImageMasterFile' do
        @images.count.should == 1
        @images.first.validity.should be false
      end

      it 'should have empty pid value' do
        @images.first.pid.should be nil
      end

      it 'should not create core_file' do
        expect { CoreFile.find("#{@images.first.pid}").to raise_error ActiveFedora::ObjectNotFoundError }
      end
    end

    context "well formed file" do
      before(:all) {
        context("#{Rails.root}/spec/fixtures/files/marcom.jpeg")
       }
      after(:all)  { clear_context }

      it 'creates success report' do
        @images.first.validity.should be true
        @images.first.modified.should be false
      end

      it 'sets original_filename to basename of file in tmp dir' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.original_filename.should == 'marcom.jpeg'
        #check for replacement of spaces and parens in file name?
      end

      it_should_behave_like "successful uploads"
    end

    context "not image file" do
      before(:all) {
        context("#{Rails.root}/spec/fixtures/files/test_doc.doc")
      }
      after(:all)  { clear_context }
      it_should_behave_like "failed uploads"
    end #end context

    context "missing title" do
      before(:all) {
        context("#{Rails.root}/spec/fixtures/files/marcom_no_title.jpg")
      }
      after(:all)  { clear_context }

      it "should return no title error" do
        @images.first.exception.should == "Missing title (IPTC Headline)"
      end

      it_should_behave_like "failed uploads"
    end

    context "missing keyword" do
      before(:all) {
        context("#{Rails.root}/spec/fixtures/files/marcom_no_keyword.jpg")
      }
      after(:all)  { clear_context }

      it "should return no keyword error" do
        @images.first.exception.should == "Missing keyword(s)"
      end

      it_should_behave_like "failed uploads"
    end

    context "backwards name" do
      before(:all) {
        context("#{Rails.root}/spec/fixtures/files/marcom_mod_name.jpg")
      }
      after(:all)  { clear_context }

      it 'creates modified report' do
        @images.count.should == 1
        @images.first.validity.should be true
        @images.first.modified.should be true
      end

      it 'sets original_filename to basename of file in tmp dir' do
        @core_file = CoreFile.find("#{@images.first.pid}")
        @core_file.original_filename.should == 'marcom_mod_name.jpg'
        #check for replacement of spaces and parens in file name?
      end

      it_should_behave_like "successful uploads"
    end

    context "bad iptc" do
      before(:all) {
        context("#{Rails.root}/spec/fixtures/files/iptc_smartquotes.jpg")
      }
      after(:all)  { clear_context }

      it 'creates modified report' do
        @images.count.should == 1
        @images.first.validity.should be true
        @images.first.modified.should be true
      end

    end

  end

end
