class Loaders::LoadReport < ActiveRecord::Base
  has_many :image_reports
  attr_accessible :timestamp, :number_of_files, :success_count, :fail_count, :name, :email, :loader

  def self.create_from_strings(user, time, results, loader_name)
    x = Loaders::LoadReport.new

    x.time        = time
    x.name             = user.full_name
    x.email            = user.email
    x.loader_name      = loader_name
    x.number_of_files  = results
    x.save! ? x : false

    return x.id
    # iterate over results to get @success_count and @fail_count
  end
end
