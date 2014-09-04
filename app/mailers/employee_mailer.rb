class EmployeeMailer < ActionMailer::Base
  default from: "drstestmailer@gmail.com"

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
      else
        git_config = ParseConfig.new('/home/vagrant/.gitconfig')
        git_config['user']['email']
      end
    end
end
