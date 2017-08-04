class PrivatizeMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def privatize_alert(pids)
    @pids  = pids

    mail(to: pick_receiver,
         subject: "[cerberus] Collection Privatized",
         content_type: "text/html")
  end

  private
    def pick_receiver
      if ["production", "secondary"].include? Rails.env
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
