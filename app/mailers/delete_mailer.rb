class DeleteMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def delete_alert(object, reason, user)
    @title = object.title || "No title set.  Uh oh!"
    @pid  = object.pid  || "No pid set.  Uh oh!"
    @reason = reason
    @user= user
    @type = object.class
    @depositor = object.depositor
    @depositor_name = get_depositor_name(object)
    @depositor_email = get_depositor_email(object)
    if @type == Collection
      @object_url = collection_url(@pid)
    elsif @type == CoreFile
      @object_url = core_file_url(@pid)
    elsif @type == Compilation
      @object_url = compilation_url(@pid)
    end
    mail(to: pick_receiver,
         subject: "[cerberus] User Requested #{@type} Deletion",
         content_type: "text/html")
  end

  private
    def pick_receiver
      if ["production", "secondary"].include? Rails.env
        "sj.sweeney@neu.edu"
      elsif ["staging"].include? Rails.env
        "e.zoller@neu.edu"
      elsif "test" == Rails.env
        "test@test.com"
      else
        if File.exist?('/home/vagrant/.gitconfig')
          git_config = ParseConfig.new('/home/vagrant/.gitconfig')
          git_config['user']['email']
        end
      end
    end

    def get_depositor_email(object)
      if !object.depositor.blank?
        user = User.find_by_nuid(object.depositor)
        if !user.email.blank?
          if !user.email.include? user.nuid
            return user.email
          end
        end
      end
      return false
    end

    def get_depositor_name(object)
      if !object.depositor.blank?
        user = User.find_by_nuid(object.depositor)
        if !user.full_name.blank?
          return user.full_name
        end
      end
      return false
    end
end
