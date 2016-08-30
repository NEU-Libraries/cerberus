class Loaders::ItemReport < ActiveRecord::Base
  belongs_to :load_report
  attr_accessible :exception, :valid, :pid, :title, :collection, :iptc, :original_file
  attr_accessible :modified, :change_type, :preview_file
  serialize :iptc

  def self.create_success(core_file, iptc, change_type)
    x = Loaders::ItemReport.new
    x.validity             = true
    x.modified             = false
    x.pid               = core_file.pid
    x.collection        = core_file.parent.pid
    x.title             = core_file.title
    x.iptc              = iptc
    x.original_file     = core_file.label
    x.change_type       = change_type
    x.save! ? x : false
  end

  def self.create_modified(exception, core_file, iptc, change_type)
    x = Loaders::ItemReport.new
    x.validity          = true
    x.modified          = true
    x.pid               = core_file.pid
    x.collection        = core_file.parent.pid
    x.title             = core_file.title
    x.exception         = exception
    x.iptc              = iptc
    x.original_file     = core_file.label
    x.change_type       = change_type
    x.save! ? x : false
  end

  def self.create_failure(exception, iptc, original_file, preview_file=false)
    x = Loaders::ItemReport.new
    x.validity             = false
    x.exception         = exception
    x.iptc              = iptc
    x.original_file     = original_file
    x.preview_file      = preview_file
    x.save! ? x : false
  end

end