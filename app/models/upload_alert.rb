class UploadAlert < ActiveRecord::Base
  attr_accessible :depositor_email, :depositor_name, :title, :type
end
