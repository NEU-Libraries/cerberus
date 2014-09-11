class MetadataMailer < ActionMailer::Base
  include AbstractController::Callbacks

  default from: "drstestmailer@gmail.com"
  after_filter :tag_as_notified


  # Generate the email
  def daily_alert_email
    @research_new            = UploadAlert.withheld_research_publications(:create)
    @research_update         = UploadAlert.withheld_research_publications(:update)

    @theses_new              = UploadAlert.withheld_theses(:create)
    @theses_update           = UploadAlert.withheld_theses(:update)

    @datasets_new            = UploadAlert.withheld_datasets(:create)
    @datasets_update         = UploadAlert.withheld_datasets(:update)

    @learning_objects_new    = UploadAlert.withheld_learning_objects(:create)
    @learning_objects_update = UploadAlert.withheld_learning_objects(:update)

    @presentations_new       = UploadAlert.withheld_presentations(:create)
    @presentations_update    = UploadAlert.withheld_presentations(:update)

    mail(to: "William Jackson <wjackson64@gmail.com>", subject: 'Daily Featured Content Uploads')
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
      tag_as_notified_helper @learning_objects_new
      tag_as_notified_helper @learning_objects_update
      tag_as_notified_helper @presentations_new
      tag_as_notified_helper @presentations_update
    end
end
