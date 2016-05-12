class Loaders::LoadReport < ActiveRecord::Base
  has_many :image_reports
  has_many :multipage_reports
  attr_accessible :timestamp, :number_of_files, :success_count, :fail_count, :modified_count, :nuid, :loader, :collection
  attr_accessible :comparison_file_pid, :preview_file_pid, :completed

  def self.create_from_strings(user, results, loader_name, collection)
    x = Loaders::LoadReport.new

    x.nuid             = user.nuid
    x.collection       = collection
    x.loader_name      = loader_name
    x.number_of_files  = results
    x.success_count    = 0
    x.fail_count       = 0
    x.modified_count   = 0
    x.completed = false
    x.save! ? x : false

    return x.id
  end

  def update_counts
    images = Loaders::ImageReport.where(load_report_id:"#{self.id}").find_all
    self.success_count = 0
    self.fail_count = 0
    self.modified_count = 0
    images.each do |i|
      if i.validity == true && i.modified == false
        self.success_count = self.success_count + 1
      elsif i.validity == true && i.modified == true
        self.modified_count = self.modified_count + 1
      else
        self.fail_count = self.fail_count + 1
      end
    end
    self.save!
  end
end
