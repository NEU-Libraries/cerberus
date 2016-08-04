require 'spec_helper'
include ApplicationHelper

describe "aggregated statistics back fill job" do
  Timecop.travel(14.days.ago) do #pretending it is two weeks ago
    let(:bill)                  { FactoryGirl.create(:bill) }
    let(:root_community)        { FactoryGirl.create(:root_community) }
    let(:test_community)        { FactoryGirl.create(:test_community, parent: root_community.pid) }
    let(:collection)            { FactoryGirl.create(:collection, parent: root_community) }
    let(:test_collection)       { FactoryGirl.create(:collection, parent: test_community) }
    let(:child_collection)      { FactoryGirl.create(:collection, parent: test_collection) }
    let(:file)                  { FactoryGirl.create(:complete_file, depositor: bill.nuid, parent: collection) }
    let(:nested_file)           { FactoryGirl.create(:complete_file, depositor: bill.nuid, parent: child_collection) }
    let(:image)                 { FactoryGirl.create(:image_master_file, depositor:bill.nuid) }
    let(:xml_alert)             { FactoryGirl.create_list(:updated_xml, 2, :pid=>file.pid) }

    before(:each) do
      image.canonize
      image.depositor              = file.depositor
      image.core_record            = file
      image.save!
      EmployeeCreateJob.new(bill.nuid, "Joe Blow").run
      employee = Employee.find_by_nuid(bill.nuid)
      employee.add_community(root_community)
      employee.save!
      @emp_col = employee.smart_collections.last
      @bill_file = FactoryGirl.create(:complete_file, depositor: bill.nuid, parent: @emp_col)
    end

    after(:each) do
      ActiveFedora::Base.destroy_all
      Impression.destroy_all
      UploadAlert.destroy_all
      Loaders::LoadReport.destroy_all
      Loaders::ItemReport.destroy_all
      XmlAlert.destroy_all
      AggregatedStatistic.destroy_all
      User.destroy_all
      Employee.destroy_all
    end

    describe "run" do

      it 'gets impressions' do  #for views, downloads, streams
        Impression.create(pid: file.pid, session_id: "doop", action: "view", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        Impression.create(pid: file.pid, session_id: "doop", action: "download", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        Impression.create(pid: file.pid, session_id: "doop", action: "stream", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:pid=>"#{file.pid}").first.views.should == 1
        AggregatedStatistic.where(:pid=>"#{file.pid}").first.downloads.should == 1
        AggregatedStatistic.where(:pid=>"#{file.pid}").first.streams.should == 1
      end

      it 'does not count uncompleted impressions' do
        Impression.create(pid: file.pid, session_id: "doop", action: "view", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "false")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:pid=>"#{file.pid}").count.should == 0
      end

      it 'aggregates impressions up to parent collection' do  #for views, downloads, streams
        Impression.create(pid: file.pid, session_id: "doop", action: "view", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        Impression.create(pid: file.pid, session_id: "doop", action: "download", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        Impression.create(pid: file.pid, session_id: "doop", action: "stream", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:pid=>"#{collection.pid}").first.views.should == 1
        AggregatedStatistic.where(:pid=>"#{collection.pid}").first.downloads.should == 1
        AggregatedStatistic.where(:pid=>"#{collection.pid}").first.streams.should == 1
      end

      it 'aggregates impressions up to parent community' do  #for views, downloads, streams
        Impression.create(pid: file.pid, session_id: "doop", action: "view", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        Impression.create(pid: file.pid, session_id: "doop", action: "download", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        Impression.create(pid: file.pid, session_id: "doop", action: "stream", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.views.should == 1
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.downloads.should == 1
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.streams.should == 1
      end

      it 'passes through nested collections and communities' do
        Impression.create(pid: nested_file.pid, session_id: "doop", action: "view", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        Impression.create(pid: nested_file.pid, session_id: "doop", action: "download", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        Impression.create(pid: nested_file.pid, session_id: "doop", action: "stream", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"file").count.should == 1
        AggregatedStatistic.where(:object_type=>"collection").count.should == 2
        AggregatedStatistic.where(:object_type=>"community").count.should == 2
        AggregatedStatistic.where(:pid=>"#{nested_file.pid}").first.views.should == 1
        AggregatedStatistic.where(:pid=>"#{nested_file.pid}").first.downloads.should == 1
        AggregatedStatistic.where(:pid=>"#{nested_file.pid}").first.streams.should == 1
        AggregatedStatistic.where(:pid=>"#{child_collection.pid}").first.views.should == 1
        AggregatedStatistic.where(:pid=>"#{child_collection.pid}").first.downloads.should == 1
        AggregatedStatistic.where(:pid=>"#{child_collection.pid}").first.streams.should == 1
        AggregatedStatistic.where(:pid=>"#{test_collection.pid}").first.views.should == 1
        AggregatedStatistic.where(:pid=>"#{test_collection.pid}").first.downloads.should == 1
        AggregatedStatistic.where(:pid=>"#{test_collection.pid}").first.streams.should == 1
        AggregatedStatistic.where(:pid=>"#{test_community.pid}").first.views.should == 1
        AggregatedStatistic.where(:pid=>"#{test_community.pid}").first.downloads.should == 1
        AggregatedStatistic.where(:pid=>"#{test_community.pid}").first.streams.should == 1
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.views.should == 1
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.downloads.should == 1
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.streams.should == 1
      end

      it 'gets upload_alerts' do  #for form_edits and user_uploads
        UploadAlert.create_from_core_file(file, :create, "single")
        UploadAlert.create_from_core_file(file, :update, "single")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"file").count.should == 1
        AggregatedStatistic.where(:pid=>"#{file.pid}").first.form_edits.should == 1
        AggregatedStatistic.where(:pid=>"#{file.pid}").first.user_uploads.should == 1
      end

      it 'aggregates upload_alerts up to parent collection' do
        UploadAlert.create_from_core_file(file, :create, "single")
        UploadAlert.create_from_core_file(file, :update, "single")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"collection").count.should == 1
        AggregatedStatistic.where(:pid=>"#{collection.pid}").first.form_edits.should == 1
        AggregatedStatistic.where(:pid=>"#{collection.pid}").first.user_uploads.should == 1
      end

      it 'aggregates upload_alerts up to parent community' do
        UploadAlert.create_from_core_file(file, :create, "single")
        UploadAlert.create_from_core_file(file, :update, "single")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"community").count.should == 1
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.form_edits.should == 1
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.user_uploads.should == 1
      end

      it 'gets filesize for user_uploads and propogates up' do
        UploadAlert.create_from_core_file(file, :create, "single")
        size = (get_core_file_size(file.pid)/1024)/1024
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:pid=>"#{file.pid}").first.size_increase.should == size
        AggregatedStatistic.where(:pid=>"#{collection.pid}").first.size_increase.should == size
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.size_increase.should == size
      end

      it 'gets item_reports' do #for loader_uploads
        parent = collection.pid
        report_id = Loaders::LoadReport.create_from_strings(bill, 0, "College of Engineering", parent)
        load_report = Loaders::LoadReport.find(report_id)
        load_report.item_reports.create_success(file, "")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"file").count.should == 1
        AggregatedStatistic.where(:pid=>"#{file.pid}").first.loader_uploads.should == 1
      end

      it 'aggregates item_reports up to parent collection' do
        parent = collection.pid
        report_id = Loaders::LoadReport.create_from_strings(bill, 0, "College of Engineering", parent)
        load_report = Loaders::LoadReport.find(report_id)
        load_report.item_reports.create_success(file, "")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"collection").count.should == 1
        AggregatedStatistic.where(:pid=>"#{collection.pid}").first.loader_uploads.should == 1
      end

      it 'aggregates item_reports up to parent community' do
        parent = collection.pid
        report_id = Loaders::LoadReport.create_from_strings(bill, 0, "College of Engineering", parent)
        load_report = Loaders::LoadReport.find(report_id)
        load_report.item_reports.create_success(file, "")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"community").count.should == 1
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.loader_uploads.should == 1
      end

      it 'gets xml_alerts' do #for xml_edits
        date = DateTime.now.+2.weeks
        xml_alert.first.pid
        XmlAlert.all.count
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"file").count.should == 1
        AggregatedStatistic.where(:pid=>"#{file.pid}").first.xml_edits.should == 2
      end

      it 'aggregates xml_alerts up to parent collection' do #for xml_edits
        date = DateTime.now.+2.weeks
        xml_alert.first.pid
        XmlAlert.all.count
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"collection").count.should == 1
        AggregatedStatistic.where(:pid=>"#{collection.pid}").first.xml_edits.should == 2
      end

      it 'aggregates xml_alerts up to parent community' do #for xml_edits
        date = DateTime.now.+2.weeks
        xml_alert.first.pid
        XmlAlert.all.count
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"community").count.should == 1
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.xml_edits.should == 2
      end

      it 'works for employee collections' do
        Impression.create(pid: @bill_file.pid, session_id: "doop", action: "view", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"file").count.should == 1
        AggregatedStatistic.where(:object_type=>"collection").count.should == 2
        AggregatedStatistic.where(:object_type=>"community").count.should == 1
        AggregatedStatistic.where(:pid=>"#{@bill_file.pid}").first.views.should == 1
        AggregatedStatistic.where(:pid=>"#{@emp_col.pid}").first.views.should == 1
        AggregatedStatistic.where(:pid=>"#{@emp_col.parent.pid}").first.views.should == 1
        AggregatedStatistic.where(:pid=>"#{root_community.pid}").first.views.should == 1
      end

      it 'fails gracefully if object no longer exists' do #this is expected that if an object no longer exists, the aggregated_statistic will not be generated for this object
        Impression.create(pid: file.pid, session_id: "doop", action: "view", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        Impression.create(pid: file.pid, session_id: "doop", action: "download", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        Impression.create(pid: file.pid, session_id: "doop", action: "stream", ip_address: "00.00.00", referrer: "direct", user_agent: "RSpec", status: "COMPLETE", public: "true")
        parent = collection.pid
        report_id = Loaders::LoadReport.create_from_strings(bill, 0, "College of Engineering", parent)
        load_report = Loaders::LoadReport.find(report_id)
        load_report.item_reports.create_success(file, "")
        UploadAlert.create_from_core_file(file, :create, "single")
        UploadAlert.create_from_core_file(file, :update, "single")
        date = DateTime.now.+2.weeks
        xml_alert.first.pid
        XmlAlert.all.count
        pid = file.pid
        file.destroy
        date = DateTime.now.+2.weeks
        @job = AggregatedStatisticsBackFillJob.new(date)
        @job.run
        AggregatedStatistic.where(:object_type=>"file").count.should == 0
        AggregatedStatistic.where(:object_type=>"collection").count.should == 0
        AggregatedStatistic.where(:object_type=>"community").count.should == 0
      end

    end
  end

  private
    def get_core_file_size(pid)
      total = 0
      cf_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
      all_possible_models = [ "ImageSmallFile", "ImageMediumFile", "ImageLargeFile",
                              "ImageMasterFile", "ImageThumbnailFile", "MsexcelFile",
                              "MspowerpointFile", "MswordFile", "PdfFile", "TextFile",
                              "ZipFile", "AudioFile", "VideoFile", "PageFile", "VideoMasterFile", "AudioMasterFile" ]
      models_stringified = all_possible_models.inject { |base, str| base + " or #{str}" }
      models_query = ActiveFedora::SolrService.escape_uri_for_query models_stringified
      content_objects = solr_query_file_size("active_fedora_model_ssi:(#{models_stringified}) AND is_part_of_ssim:#{full_pid(pid)}")
      content_objects.map{|doc| total += doc.file_size.to_i}
      return total
    end

    def full_pid(pid)
      return ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{pid}"
    end

    def solr_query_file_size(query_string)
      row_count = ActiveFedora::SolrService.count(query_string)
      query_result = ActiveFedora::SolrService.query(query_string, :fl => "id file_size_tesim", :rows => row_count)
      return query_result.map { |x| SolrDocument.new(x) }
    end

end
