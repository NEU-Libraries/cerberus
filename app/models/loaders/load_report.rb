class Loaders::LoadReport < ActiveRecord::Base
  attr_accessible :timestamp, :number_of_files, :success_count, :fail_count, :name, :email, :loader

  def initialize(user, time, results, loader_name)
    @timestamp        = time
    @name             = user.full_name
    @email            = user.email
    @load             = loader_name
    @number_of_files  = results.length
    # iterate over results to get @success_count and @fail_count
  end
end
