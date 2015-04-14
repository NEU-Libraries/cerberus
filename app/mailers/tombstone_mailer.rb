class TombstoneMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def tombstone_alert(core_file)
    @title = core_file.title || "No title set.  Uh oh!"
    @pid  = core_file.pid  || "No pid set.  Uh oh!"
    mail(to: pick_receiver,
         subject: "[cerberus] User Requested Deletion",
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
