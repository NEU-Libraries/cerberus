class XmlMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def xml_edited_alert(core_file, user, new_tmp_file_str, old_tmp_file_str)
    @name = user.pretty_name || "No name set.  Uh oh!"
    @email = user.email || "No email set.  Uh oh!"
    @pid  = core_file.pid  || "No pid set.  Uh oh!"
    @diff_css = Diffy::CSS
    @diff = Diffy::Diff.new(old_tmp_file_str, new_tmp_file_str, :include_plus_and_minus_in_html => true, :context => 1).to_s(:html)

    # mail.attachments['new.xml'] = File.read(new_tmp_file)
    # mail.attachments['old.xml'] = File.read(old_tmp_file)

    mail(to: pick_receiver,
         subject: "[cerberus] XML Edited for #{core_file.title} - #{core_file.pid}",
         content_type: "text/html")
  end

  private
    def pick_receiver
      if ["production"].include? Rails.env
        "Library-DRS-Metadata@neu.edu"
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
