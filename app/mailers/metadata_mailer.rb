class MetadataMailer < ActionMailer::Base
  include AbstractController::Callbacks

  default from: "notifier@repository.library.northeastern.edu"
  after_filter :tag_as_notified, only:[:daily_alert_email]
  after_filter :tag_as_notified_nonfeatured, only:[:daily_nonfeatured_alert_email]


  # Generate the email
  def daily_alert_email
    @research_new            = UploadAlert.withheld_research_publications(:create)
    @research_update         = UploadAlert.withheld_research_publications(:update)

    @theses_new              = UploadAlert.withheld_theses(:create)
    @theses_update           = UploadAlert.withheld_theses(:update)

    @datasets_new            = UploadAlert.withheld_datasets(:create)
    @datasets_update         = UploadAlert.withheld_datasets(:update)

    @technical_reports_new            = UploadAlert.withheld_technical_reports(:create)
    @technical_reports_update         = UploadAlert.withheld_technical_reports(:update)

    @learning_objects_new    = UploadAlert.withheld_learning_objects(:create)
    @learning_objects_update = UploadAlert.withheld_learning_objects(:update)

    @presentations_new       = UploadAlert.withheld_presentations(:create)
    @presentations_update    = UploadAlert.withheld_presentations(:update)

    @other_pubs_new          = UploadAlert.withheld_other_pubs(:create)
    @other_pubs_update       = UploadAlert.withheld_other_pubs(:update)

    @monographs_new       = UploadAlert.withheld_monographs(:create)
    @monographs_update    = UploadAlert.withheld_monographs(:update)

    count = 0
    count += @research_new.count
    count += @research_update.count

    count += @theses_new.count
    count += @theses_update.count

    count += @datasets_new.count
    count += @datasets_update.count

    count += @technical_reports_new.count
    count += @technical_reports_update.count

    count += @learning_objects_new.count
    count += @learning_objects_update.count

    count += @presentations_new.count
    count += @presentations_update.count

    count += @other_pubs_new.count
    count += @other_pubs_update.count

    count += @monographs_new.count
    count += @monographs_update.count

    if count == 0
      self.message.perform_deliveries = false
    else
      if ["production", "secondary"].include? Rails.env
        mail(to: "Metadata Mailing List <Library-DRS-Metadata@neu.edu>", subject: "Daily Featured Content Uploads and Updates - #{count} items", content_type: "text/html")
      elsif "test" == Rails.env
        mail(to: "Test <test@test.com>", subject: "Daily Featured Content Uploads and Updates - #{count} items")
      else
        if File.exist?('/home/vagrant/.gitconfig')
          git_config = ParseConfig.new('/home/vagrant/.gitconfig')
          address = git_config['user']['email']
          mail(to: "Developer <#{address}>", subject: "Daily Featured Content Uploads and Updates - #{count} items",
          content_type: "text/html")
        end
      end
    end
  end

  def daily_nonfeatured_alert_email
    @misc_new               = UploadAlert.withheld_misc(:create)
    @misc_update            = UploadAlert.withheld_misc(:update)

    @nonfeatured_new        = UploadAlert.withheld_nonfeatured(:create)
    @nonfeatured_update     = UploadAlert.withheld_nonfeatured(:update)

    @collections_new        = UploadAlert.withheld_collections(:create)
    @collections_update     = UploadAlert.withheld_collections(:update)

    nonfeatured_count = 0

    nonfeatured_count += @misc_new.count
    nonfeatured_count += @misc_update.count

    nonfeatured_count += @nonfeatured_new.count
    nonfeatured_count += @nonfeatured_update.count

    nonfeatured_count += @collections_new.count
    nonfeatured_count += @collections_update.count

    if nonfeatured_count == 0
      self.message.perform_deliveries = false
    else
      if ["production", "secondary"].include? Rails.env
        mail(to: "Sarah <sj.sweeney@neu.edu>, Library-DRS-Metadata@northeastern.edu", subject: "Daily Non-Featured Content and Collection Uploads and Updates - #{nonfeatured_count} items", content_type: "text/html")
      elsif "test" == Rails.env
        mail(to: "Test <test@test.com>", subject: "Daily Non-Featured Content and Collection Uploads and Updates - #{nonfeatured_count} items")
      else
        if File.exist?('/home/vagrant/.gitconfig')
          git_config = ParseConfig.new('/home/vagrant/.gitconfig')
          address = git_config['user']['email']
          mail(to: "Developer <#{address}>", subject: "Daily Non-Featured Content and Collection Uploads and Updates - #{nonfeatured_count} items",
          content_type: "text/html")
        end
      end
    end
  end

  private
    def tag_as_notified_helper(enum)
      enum.each do |alert|
        alert.notified = true
        alert.save
      end
    end

    def tag_as_notified
      tag_as_notified_helper @research_new
      tag_as_notified_helper @research_update
      tag_as_notified_helper @theses_new
      tag_as_notified_helper @theses_update
      tag_as_notified_helper @datasets_new
      tag_as_notified_helper @datasets_update
      tag_as_notified_helper @technical_reports_new
      tag_as_notified_helper @technical_reports_update
      tag_as_notified_helper @learning_objects_new
      tag_as_notified_helper @learning_objects_update
      tag_as_notified_helper @presentations_new
      tag_as_notified_helper @presentations_update
      tag_as_notified_helper @other_pubs_new
      tag_as_notified_helper @other_pubs_update
      tag_as_notified_helper @monographs_new
      tag_as_notified_helper @monographs_update
    end

    def tag_as_notified_nonfeatured
      tag_as_notified_helper @misc_new
      tag_as_notified_helper @misc_update
      tag_as_notified_helper @nonfeatured_new
      tag_as_notified_helper @nonfeatured_update
      tag_as_notified_helper @collections_new
      tag_as_notified_helper @collections_update
    end
end
