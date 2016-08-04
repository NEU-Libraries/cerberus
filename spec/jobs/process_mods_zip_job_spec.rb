require 'spec_helper'
include SpreadsheetHelper

describe ProcessModsZipJob do
  before(:all) do
    `mysql -u "#{ENV["HANDLE_USERNAME"]}" < "#{Rails.root}"/spec/fixtures/files/handlesTEST.sql`
    @client = Mysql2::Client.new(:host => "#{ENV["HANDLE_TEST_HOST"]}", :username => "#{ENV["HANDLE_TEST_USERNAME"]}", :password => "#{ENV["HANDLE_TEST_PASSWORD"]}", :database => "#{ENV["HANDLE_TEST_DATABASE"]}")
    @loader_name = "MODS Spreadsheet"
    @user = FactoryGirl.create(:admin)
  end

  after(:all) do
    @client.query("DROP DATABASE #{ENV["HANDLE_TEST_DATABASE"]};")
    @user.destroy if @user
  end

  shared_examples_for "successful mods" do
    it "assigns mods values" do
      cf.title.should == "Annual report of the Citywide Educational Coalition, 1981-1982."
      cf.mods.title_info.non_sort.should == ["The"]
      cf.mods.corporate_name(0).usage.should == ["primary"]
      cf.mods.corporate_name(0).name_part.should == ["Citywide Educational Coalition"]
      cf.mods.corporate_name(0).value_uri.should == ["URI for value"]
      cf.mods.corporate_name(0).authority.should == ["lcsh"]
      cf.mods.corporate_name(0).authority_uri.should == ["lcsh URI"]
      cf.mods.corporate_name(0).role.role_term.should == ["Creator"]
      cf.mods.corporate_name(0).role.role_term.value_uri.should == ["http://id.loc.gov/vocabulary/relators/cre"]
      cf.mods.corporate_name(0).role.role_term.authority.should == ["marcrelator"]
      cf.mods.corporate_name(0).role.role_term.authority_uri.should == ["http://id.loc.gov/vocabulary/relators"]
      cf.mods.corporate_name(0).role.role_term.type.should == ["text"]
      cf.mods.personal_name(0).name_part_given.should == ["Marcus"]
      cf.mods.personal_name(0).name_part_family.should == ["Stannard"]
      cf.mods.personal_name(0).value_uri.should == ["URI for Stannard"]
      cf.mods.personal_name(0).authority.should == ["lcsh"]
      cf.mods.personal_name(0).authority_uri.should == ["lcsh URI"]
      cf.mods.personal_name(0).role.role_term.should == ["Creator"]
      cf.mods.personal_name(0).role.role_term.value_uri.should == ["http://id.loc.gov/vocabulary/relators/cre"]
      cf.mods.personal_name(0).role.role_term.authority.should == ["marcrelator"]
      cf.mods.personal_name(0).role.role_term.authority_uri.should == ["http://id.loc.gov/vocabulary/relators"]
      cf.mods.personal_name(0).role.role_term.type.should == ["text"]
      cf.mods.personal_name(0).affiliation.should == ["TREAD, Inc."]
      cf.mods.type_of_resource.should == ["text"]
      cf.mods.genre.should == ["reports", "fiction"]
      cf.mods.genre.authority.should == ["aat", "aat"]
      cf.mods.origin_info.date_created.should == ["1981"]
      cf.mods.origin_info.date_created.point.should == ["start"]
      cf.mods.origin_info.date_created_end.should == ["1982"]
      cf.mods.origin_info.date_issued.should == ["1982"]
      cf.mods.origin_info.publisher.should == ["Citywide Educational Coalition"]
      cf.mods.origin_info.place.place_term.should == ["Boston, Massachusetts"]
      cf.mods.origin_info.issuance.should == ["serial"]
      cf.mods.origin_info.frequency.should == ["annual"]
      cf.mods.origin_info.frequency.authority.should == ["marcfrequency"]
      cf.mods.physical_description.extent.should == ["16 pages"]
      cf.mods.physical_description.digital_origin.should == ["reformatted digital"]
      cf.mods.physical_description.reformatting_quality.should == ["preservation"]
      cf.mods.language.language_term.should == ["English"]
      cf.mods.language.language_term.language_term_type.should == ["text"]
      cf.mods.language.language_term.language_authority.should == ["iso639-2b"]
      cf.mods.language.language_term.language_authority_uri.should == ["http://id.loc.gov/vocabulary/iso639-2"]
      cf.mods.language.language_term.language_value_uri.should == ["http://id.loc.gov/vocabulary/iso639-2/eng"]
      cf.description.should == "abstract goes here"
      cf.mods.access_condition(0).should == ["Permission to publish materials from this collection must be requested from Archives and Special Collections, Northeastern University."]
      cf.mods.access_condition(0).type.should == ["use and reproduction"]
      cf.mods.note(0).should == ["this is provenance note"]
      cf.mods.note(0).type.should == ["provenance"]
      cf.mods.subject.count.should == 10
      cf.mods.subject(0).topic(0).should == ["African American students"]
      cf.mods.subject(0).topic(1).should == ["Massachusetts"]
      cf.mods.subject(0).topic(2).should == ["Boston"]
      cf.mods.subject(0).authority.should == ["lcsh"]
      cf.mods.subject(0).value_uri.should == ["Value URI"]
      cf.mods.subject(1).topic(0).should == ["African Americans"]
      cf.mods.subject(1).topic(1).should == ["Education"]
      cf.mods.subject(1).topic(2).should == ["Massachusetts"]
      cf.mods.subject(1).topic(3).should == ["Boston"]
      cf.mods.subject(1).value_uri.should == ["Value URI"]
      cf.mods.subject(2).topic(0).should == ["Civil rights"]
      cf.mods.subject(2).topic(1).should == ["Massachusetts"]
      cf.mods.subject(2).topic(2).should == ["Boston"]
      cf.mods.subject(2).authority.should == ["lcsh"]
      cf.mods.subject(2).value_uri.should == []
      cf.mods.subject(3).topic(0).should == ["Public schools"]
      cf.mods.subject(3).topic(1).should == ["Massachusetts"]
      cf.mods.subject(3).topic(2).should == ["Boston"]
      cf.mods.subject(3).authority.should == ["lcsh"]
      cf.mods.subject(3).value_uri.should == []
      cf.mods.subject(4).name.name_part.should == ["Citywide Educational Coalition"]
      cf.mods.subject(4).name.value_uri.should == ["URI for value"]
      cf.mods.subject(4).name.authority.should == ["lcsh"]
      cf.mods.subject(4).name.authority_uri.should == ["lcsh URI"]
      cf.mods.subject(5).name.name_part_given.should == ["W. Arthur (Wendell Arthur)"]
      cf.mods.subject(5).name.name_part_family.should == ["Garrity"]
      cf.mods.subject(5).name.name_part_date.should == ["1920-1999"]
      cf.mods.subject(5).name.value_uri.should == ["Value URI"]
      cf.mods.subject(5).name.authority.should == ["lcsh"]
      cf.mods.subject(5).name.authority_uri.should == ["lcsh URI"]
      cf.mods.related_item(0).title_info.title.should == ["Annual report of the Citywide Educational Coalition, 1981-1982."]
      cf.mods.related_item(0).type.should == ["original"]
      cf.mods.related_item(0).location.physical_location.should == ["Box 1, Folder 3"]
      cf.mods.related_item(0).identifier.should == ["M130.B01.F003.001"]
      cf.mods.related_item(1).title_info.title.should == ["Citywide Educational Coalition records (M130)"]
      cf.mods.related_item(1).type.should == ["host"]
      cf.mods.related_item(2).title_info.title.should == ["Governance"]
      cf.mods.related_item(2).type.should == ["series"]
      # defaults
      cf.mods.record_info.record_content_source.should == ["Northeastern University Libraries"]
      cf.mods.record_info.record_origin.should == ["Generated from spreadsheet"]
      cf.mods.record_info.language_of_cataloging.language_term.should == ["English"]
      cf.mods.record_info.language_of_cataloging.language_term.language_authority.should == ["iso639-2b"]
      cf.mods.record_info.language_of_cataloging.language_term.language_authority_uri.should == ["http://id.loc.gov/vocabulary/iso639-2"]
      cf.mods.record_info.language_of_cataloging.language_term.language_term_type.should == ["text"]
      cf.mods.record_info.language_of_cataloging.language_term.language_value_uri.should == ["http://id.loc.gov/vocabulary/iso639-2/eng"]
      cf.mods.record_info.description_standard.should == ["RDA"]
      cf.mods.record_info.description_standard.authority.should == ["marcdescription"]
      cf.mods.record_info.record_creation_date.should == [DateTime.now.strftime("%F")]
      cf.mods.physical_description.form.should == ["electronic"]
      cf.mods.physical_description.form.authority.should == ["marcform"]
    end
  end

  context "creates preview file" do
    before(:all) do
      spreadsheet_file_path = "#{Rails.root}/spec/fixtures/files/demo_mods_new_file/demo_mods_new_file.xlsx"
      copyright = ""
      @parent = FactoryGirl.create(:root_collection)
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      file_name = File.basename(spreadsheet_file_path)
      @new_path = tempdir.join(file_name).to_s
      FileUtils.cp(spreadsheet_file_path, @new_path)
      permissions = @parent.permissions
      @report_id = Loaders::LoadReport.create_from_strings(@user, 0, @loader_name, @parent.pid)
      @lr = Loaders::LoadReport.find("#{@report_id}")
      ProcessModsZipJob.new(@loader_name, spreadsheet_file_path, @parent, copyright, @user, permissions, @report_id, false, @user.nuid, true).run
    end

    it "should create preview file" do
      @lr.reload
      CoreFile.exists?(@lr.preview_file_pid).should be true
    end

    it "should set depositor to current user" do
      @lr.reload
      cf = CoreFile.find(@lr.preview_file_pid)
      cf.depositor.should == @user.nuid
    end

    it "should set the number of files to the load report" do
      @lr.reload
      @lr.number_of_files.should == 4
      @lr.item_reports.length.should == 0 #no image reports created when its a preview
    end

    it_should_behave_like "successful mods" do
      let(:cf) {
        @lr.reload
        CoreFile.find(@lr.preview_file_pid)
       }
    end

    after :all do
      Loaders::LoadReport.destroy_all
      Loaders::ItemReport.destroy_all
      ActiveFedora::Base.destroy_all
      FileUtils.rm("#{@new_path}")
      FileUtils.rm_rf(Pathname.new("#{Rails.application.config.tmp_path}/")+"demo_mods_new_file")
    end
  end

  context "creates new core files" do
    before(:all) do
      spreadsheet_file_path = "#{Rails.root}/spec/fixtures/files/demo_mods_new_file/demo_mods_new_file.xlsx"
      copyright = ""
      @parent = FactoryGirl.create(:root_collection)
      tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
      dir_name = File.dirname(spreadsheet_file_path)
      file_name = File.basename(spreadsheet_file_path, ".*")
      @new_path = tempdir.join(file_name).to_s
      FileUtils.cp_r(dir_name, @new_path)
      permissions = @parent.permissions
      @report_id = Loaders::LoadReport.create_from_strings(@user, 0, @loader_name, @parent.pid)
      @lr = Loaders::LoadReport.find("#{@report_id}")
      @lr.number_of_files = 4
      @lr.save!
      new_file = @new_path +"/demo_mods_new_file.xlsx"
      ProcessModsZipJob.new(@loader_name, new_file, @parent, copyright, @user, permissions, @report_id, false, @user.nuid, nil).run
    end

    it "should set depositor to current user" do
      CoreFile.exists?(@lr.item_reports[0].pid).should be true
    end

    it "should set the correct number of files" do
      @lr.reload
      @lr.number_of_files.should == 4
      @lr.item_reports.length.should == 4
      @lr.fail_count.should == 3
      @lr.success_count.should == 1
    end

    it_should_behave_like "successful mods" do
      let(:cf) {
        @lr.reload
        CoreFile.find(@lr.item_reports[0].pid)
       }
    end

    it "should fail if no title" do
      @lr.reload
      failure = @lr.item_reports[1]
      failure.validity.should == false
      failure.exception.should == "Must have a title"
    end

    it "should fail if no keywords" do
      @lr.reload
      failure = @lr.item_reports[2]
      failure.validity.should == false
      failure.exception.should == "Must have at least one keyword"
    end

    it "should fail if content file does not exist" do
      @lr.reload
      failure = @lr.item_reports[3]
      failure.validity.should == false
      failure.exception.should == "File specified does not exist"
    end

    after :all do
      Loaders::LoadReport.destroy_all
      Loaders::ItemReport.destroy_all
      ActiveFedora::Base.destroy_all
      FileUtils.rm_rf(Pathname.new("#{Rails.application.config.tmp_path}/")+"demo_mods_new_file")
    end
  end
end
