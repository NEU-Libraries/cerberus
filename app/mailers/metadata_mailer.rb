class MetadataMailer < ActionMailer::Base
  include AbstractController::Callbacks

  default from: "drstestmailer@gmail.com"
  after_filter :tag_as_notified


  # Generate the email 
  def daily_alert_email
    @research = UploadAlert.withheld_research_publications
    @theses = UploadAlert.withheld_theses 
    @datasets = UploadAlert.withheld_datasets 
    @learning_objects = UploadAlert.withheld_learning_objects
    @presentations = UploadAlert.withheld_presentations
    mail(to: "William Jackson <wjackson64@gmail.com>", subject: 'Welcome to My Awesome Site')
  end

  private 
    def tag_as_notified_helper(enum)
      enum.each do |alert| 
        alert.notified = true 
        alert.save 
      end
    end

    def tag_as_notified 
      tag_as_notified_helper @research 
      tag_as_notified_helper @theses 
      tag_as_notified_helper @datasets 
      tag_as_notified_helper @learning_objects 
      tag_as_notified_helper @presentations 
    end
end
