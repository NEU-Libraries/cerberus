class MoveMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def move_alert(core_file, reason, collection_url)
    @title = core_file.title || "No title set.  Uh oh!"
    @pid  = core_file.pid  || "No pid set.  Uh oh!"
    @reason = reason
    @collection_url = collection_url
    mail(to: pick_receiver,
         subject: "[cerberus] User Requested File Move",
         content_type: "text/html")
  end

  private
    def pick_receiver
      if ["production"].include? Rails.env
        "sj.sweeney@neu.edu"
      elsif "test" == Rails.env
        "test@test.com"
      else
        if File.exist?('/home/vagrant/.gitconfig')
          git_config = ParseConfig.new('/home/vagrant/.gitconfig')
          git_config['user']['email']
        end
      end
    end
end
