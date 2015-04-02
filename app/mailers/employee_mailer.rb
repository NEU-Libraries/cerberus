class EmployeeMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"

  def new_employee_alert(employee)
    @name = employee.name || "No name set.  Uh oh!"
    @nuid = employee.nuid || "No nuid set.  Uh oh!"
    @pid  = employee.pid  || "No pid set.  Uh oh!"
    mail(to: pick_receiver,
         subject: "[cerberus] New Employee Created",
         content_type: "text/html")
  end

  private
    def pick_receiver
      if ["staging", "production"].include? Rails.env
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
