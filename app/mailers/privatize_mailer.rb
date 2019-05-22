class PrivatizeMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def privatize_alert(col_pid, pids)
    @col_pid = col_pid
    @pids    = pids

    mail(to: pick_receiver,
         subject: "[cerberus] Collection Privatized - #{col_pid}",
         content_type: "text/html")
  end

  private
    def pick_receiver
      if ["production", "secondary", "staging"].include? Rails.env
        "sj.sweeney@northeastern.edu, p.yott@northeastern.edu"
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
