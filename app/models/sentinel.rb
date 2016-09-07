class Sentinel < ActiveRecord::Base
  attr_accessible :set_pid, :permanent, :email, :audio_master, :audio, :image_master,
                  :image_large, :image_medium, :image_small, :mspowerpoint, :msexcel,
                  :msword, :page, :pdf, :text, :video_master, :video, :zip, :pid_list,
                  :core_file

  serialize :core_file, Hash

  serialize :audio_master, Hash
  serialize :audio, Hash
  serialize :image_master, Hash
  serialize :image_large, Hash
  serialize :image_medium, Hash
  serialize :image_small, Hash
  serialize :mspowerpoint, Hash
  serialize :msexcel, Hash
  serialize :msword, Hash
  serialize :page, Hash
  serialize :pdf, Hash
  serialize :text, Hash
  serialize :video_master, Hash
  serialize :video, Hash
  serialize :zip, Hash

  serialize :pid_list, Array
end
