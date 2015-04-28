# -*- coding: utf-8 -*-

class Loaders::MarcomsController < ApplicationController
  include Cerberus::Controller
  before_filter :authenticate_user!
  before_filter :verify_group

  def new
    @parent = Community.find("neu:8s45qc456")
    @collections_options = Array.new
    cols = @parent.child_collections.sort_by{|c| c.title}
    cols.each do |child|
      @collections_options.push([child.title, child.pid])
      children = child.child_collections.sort_by{|c| c.title}
      children.each do |c|
        @collections_options.push([" - #{c.title}", c.pid])
      end
    end
    render 'loaders/new', locals: { collections_options: @collections_options}
  end

  def create
    begin
      # check error condition No files
      return json_error("Error! No file to save") if !params.has_key?(:file)

      file = params[:file]
      parent = params[:parent]
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
        process_file(file, parent)
      end
    rescue => exception
      logger.error "MarcomsController::create rescued #{exception.class}\n\t#{exception.to_s}\n #{exception.backtrace.join("\n")}\n\n"
      email_handled_exception(exception)
      json_error "Error occurred while creating file."
    ensure
      # remove the tempfile (only if it is a temp file)
      file.tempfile.delete if file.respond_to?(:tempfile)
    end
  end

  def show
  end

  protected
    def process_file(file, parent)
      if virus_check(file) == 0
        tempdir = Rails.root.join("tmp")
        uniq_hsh = Digest::MD5.hexdigest("#{file.original_filename}")[0,2]
        file_name = "#{Time.now.to_i.to_s}-#{uniq_hsh}"
        new_path = tempdir.join(file_name).to_s
        new_file = "#{new_path}.zip"
        FileUtils.mv(file.tempfile.path, new_file)
        # send to job
        Cerberus::Application::Queue.push(ProcessZipJob.new(new_file.to_s, new_path, file_name, parent))
        redirect_to "/my_loaders"
      else
        render :json => [{:error => "Error creating file."}]
      end
    end

    def json_error(error, name=nil, additional_arguments={})
      args = {:error => error}
      args[:name] = name if name
      render additional_arguments.merge({:json => [args]})
    end

    def empty_file?(file)
      (file.respond_to?(:tempfile) && file.tempfile.size == 0) || (file.respond_to?(:size) && file.size == 0)
    end

    def terms_accepted?
      params[:terms_of_service] == '1'
    end

    def virus_check( file)
      stat = Cerberus::ContentFile.virus_check(file)
      flash[:error] = "Virus checking did not pass for #{File.basename(file.path)} status = #{stat}" unless stat == 0
      stat
    end

  private

    def verify_group
      # if user is not part of the marcom_loader grouper group, bounce them
    end
end
