class LoaderMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def load_alert(load, user)
    @load = load
    @user = user
    mail(to: pick_receiver,
         subject: "[DRS] Load Complete",
         content_type: "text/html")
  end

  private
    def pick_receiver
      if ["production", "secondary"].include? Rails.env
        @user.email
      elsif ["staging"].include? Rails.env
        @user.email
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
