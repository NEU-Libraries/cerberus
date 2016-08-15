class SentinelsController < ApplicationController
  def new
    @sentinel = Sentinel.new
    @content_list = [["Audio Master", "audio_master"],
                    ["Audio", "audio"],
                    ["Image Master", "image_master"],
                    ["Image Large", "image_large"],
                    ["Image Medium", "image_medium"],
                    ["Image Small", "image_small"],
                    ["Powerpoint", "mspowerpoint"],
                    ["Excel", "msexcel"],
                    ["Word ", "msword"],
                    ["Multipage", "page"],
                    ["Pdf", "pdf"],
                    ["Text", "text"],
                    ["Video Master", "video_master"],
                    ["Video", "video"],
                    ["Zip", "zip"]]
  end

  def create
    set = ActiveFedora::Base.find(parent: params[:parent], cast: true)

    sentinel = Sentinel.new(params["sentinel"].merge(set_pid: set.pid))
    sentinel.save!
    flash[:notice] = "#{sentinel.id}"
    redirect_to new_sentinel_path and return
  end
end
