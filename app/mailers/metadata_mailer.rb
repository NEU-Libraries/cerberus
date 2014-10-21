class MetadataMailer < ActionMailer::Base
  include AbstractController::Callbacks

  default from: "notifier@repository.lib.neu.edu"
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

    count = 0
    count += @research_new.count
    count += @research_update.count

    count += @theses_new.count
    count += @theses_update.count

    count += @datasets_new.count
    count += @datasets_update.count

    count += @learning_objects_new.count
    count += @learning_objects_update.count

    count += @presentations_new.count
    count += @presentations_update.count

    if ["staging", "production"].include? Rails.env
      mail(to: "Sarah Sweeney <sj.sweeney@neu.edu>", subject: "Daily Featured Content Uploads and Updates - #{count} items")
    elsif "test" == Rails.env
      mail(to: "Test <test@test.com>", subject: "Daily Featured Content Uploads and Updates - #{count} items")
    else
      git_config = ParseConfig.new('/home/vagrant/.gitconfig')
      address = git_config['user']['email']
      mail(to: "Developer <#{address}>", subject: "Daily Featured Content Uploads and Updates - #{count} items")
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
      tag_as_notified_helper @learning_objects_new
      tag_as_notified_helper @learning_objects_update
      tag_as_notified_helper @presentations_new
      tag_as_notified_helper @presentations_update
    end
end
