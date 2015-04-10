class XmlAlert < ActiveRecord::Base
  after_initialize :not_notified

  attr_accessible :pid, :name, :email, :old_file_str, :new_file_str, :diff, :notified

  def self.create_from_strings(core_file, user, old_file_str, new_file_str)

    x = XmlAlert.new

    x.pid               = core_file.pid
    x.name              = user.full_name
    x.email             = user.email
    x.title             = core_file.title
    x.old_file_str      = old_file_str
    x.new_file_str      = new_file_str
    x.diff              = Diffy::Diff.new(old_file_str, new_file_str, :include_plus_and_minus_in_html => true, :context => 1).to_s(:html)
    x.save! ? x : false
  end

  private
    def not_notified
      self.notified = false if self.notified.nil?
    end
end
