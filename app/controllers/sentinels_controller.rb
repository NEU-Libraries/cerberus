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

    @set = ActiveFedora::Base.find(params[:parent], cast: true)

    if @set.class == Collection
      @collection = true
      flash[:alert] = "Core File permissions are mandatory for Sentinels belonging to a Collection. Any disabled models will inherit their permissions from the Core File."
    else
      flash[:alert] = "Disabled models will receive no changes. Enabled models will have thier permissions wiped clean, and replaced with whatever is chosen on this form."
    end
  end

  def create
    sentinel = Sentinel.new(params["sentinel"])
    sentinel.save!

    Cerberus::Application::Queue.push(SentinelJob.new(sentinel.id))

    flash[:notice] = "A Sentinel was created, and is now effecting change."
    redirect_to(polymorphic_path(ActiveFedora::Base.find(sentinel.set_pid, cast: true))) and return
  end

  def edit
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

    @sentinel = Sentinel.find(params[:id])
    @set = ActiveFedora::Base.find(@sentinel.set_pid, cast: true)

    if @set.class == Collection
      @collection = true
    end
  end
end
