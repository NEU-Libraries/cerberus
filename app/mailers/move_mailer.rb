class MoveMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def move_alert(object, reason, collection_url, user)
    @title = object.title || "No title set.  Uh oh!"
    @pid  = object.pid  || "No pid set.  Uh oh!"
    @reason = reason
    @collection_url = collection_url
    @user= user
    @type = object.class
    if @type == Collection
      @object_url = collection_url(@pid)
    elsif @type == CoreFile
      @object_url = core_file_url(@pid)
    end
    mail(to: pick_receiver,
         subject: "[cerberus] User Requested #{@type} Move",
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
