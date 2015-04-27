class Loaders::MarcomController < ApplicationController
  before_filter :authenticate_user!
  before_filter :verify_group

  def new
    @parent = Community.find("neu:8s45qc00v")
    @collections_options = Array.new
    cols = @parent.child_collections.sort_by{|c| c.title}
    cols.each do |child|
      @collections_options.push([child.title, child.pid])
      children = child.child_collections.sort_by{|c| c.title}
      children.each do |c|
        @collections_options.push([" - #{c.title}", c.pid])
      end
    end
    render 'loaders/new', locals: { collections_options: @collections_options }
  end

  def create
    begin
      # check error condition No files
      return json_error("Error! No file to save") if !params.has_key?(:file)

      file = params[:file]
      if !file
        flash[:error] = "Error! No file for upload"
        redirect_to(:back) and return
      elsif (empty_file?(file))
        flash[:error] = "Error! Zero Length File!"
        redirect_to(:back) and return
      elsif (!terms_accepted?)
        flash[:error] = "You must accept the terms of service!"
        redirect_to(:back) and return
      else
        process_file(file)
      end
    rescue Exception => exception
    ensure
      # remove the tempfile (only if it is a temp file)
      file.tempfile.delete if file.respond_to?(:tempfile)
    end
  end

  def show
  end

  protected
    def process_file(file)
      if virus_check(file) == 0
        # send to job?
        new_path = move_file_to_tmp(file)
        Cerberus::Application::Queue.push(ProcessZipJob.new(file, new_path))
        redirect_to my_loaders_path
      else
        render :json => [{:error => "Error creating file."}]
      end
    end

  private

    def verify_group
      # if user is not part of the marcom_loader grouper group, bounce them
    end
end
