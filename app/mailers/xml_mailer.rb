class XmlMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def xml_edited_alert(core_file, user, new_tmp_file, old_tmp_file)
    @name = user.pretty_name || "No name set.  Uh oh!"
    @email = user.email || "No email set.  Uh oh!"
    @pid  = core_file.pid  || "No pid set.  Uh oh!"

    mail.attachments['new.xml'] = File.read(new_tmp_file)
    mail.attachments['old.xml'] = File.read(old_tmp_file)

    mail(to: pick_receiver,
         subject: "[cerberus] XML Edited for #{core_file.title} - #{core_file.pid}",
         content_type: "text/html")
  end

  private
    def pick_receiver
      if ["staging", "production"].include? Rails.env
        "Library-DRS-Metadata@neu.edu"
      elsif "test" == Rails.env
        "test@test.com"
      else
        git_config = ParseConfig.new('/home/vagrant/.gitconfig')
        git_config['user']['email']
      end
    end
end
