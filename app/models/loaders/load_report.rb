class Loaders::LoadReport < ActiveRecord::Base
  has_many :image_reports
  attr_accessible :timestamp, :number_of_files, :success_count, :fail_count, :nuid, :loader, :collection

  def self.create_from_strings(user, results, loader_name, collection)
    x = Loaders::LoadReport.new

    x.nuid             = user.nuid
    x.collection       = collection
    x.loader_name      = loader_name
    x.number_of_files  = results
    x.success_count    = 0
    x.fail_count       = 0
    x.save! ? x : false

    return x.id
  end

  #this doesn't do anything yet
  def update_counts(report_id)
    r = Loaders::LoadReport.find(report_id)
    images = Loaders::ImageReport.where(load_report_id:"#{@report.id}").find_all
    images.each do |i|
      if i.validity == true
        r.success_count = r.success_count + 1
      else
        r.fail_count = r.fail_count + 1
      end
    end
    r.save!
  end
end
