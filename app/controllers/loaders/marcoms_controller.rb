# -*- coding: utf-8 -*-

class Loaders::MarcomsController < ApplicationController
  include Cerberus::Controller
  include MimeHelper

  before_filter :authenticate_user!
  before_filter :verify_group

  def new
    @parent = Community.find("neu:pn89d6966")
    @collections_options = Array.new
    cols = @parent.child_collections.sort_by{|c| c.title}
    cols.each do |child|
      @collections_options.push([child.title, child.pid])
      children = child.child_collections.sort_by{|c| c.title}
      children.each do |c|
        @collections_options.push([" - #{c.title}", c.pid])
        children_next = c.child_collections.sort_by{|c| c.title}
        children_next.each do |c|
          @collections_options.push(["  -- #{c.title}", c.pid])
        end
      end
    end
    @page_title = "Marketing and Communications Loader"
    render 'loaders/new', locals: { collections_options: @collections_options}
  end

  def create
    @copyright = 'Marketing and Communications images are for use only within the context of Northeastern University. Appropriate uses include: Northeastern University-related websites, Northeastern University-based print/web publications and for speaking appearances when acting as a representative of Northeastern University. Images should be credited: "Photographer Name/Northeastern University.” Images are not to be used for self-promotional purposes outside of Northeastern University such as LinkedIn, Facebook or in commercial/external publications such as advertisements, books or magazines without written permission from Northeastern Marketing and Communications. For more information, please contact the senior staff photographer in the office of Marketing and Communications at 617.373.6767'
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
        process_file(file, parent, @copyright)
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

  def index
    @loads = Loaders::LoadReport.where('loader_name = "marcom"', true).find_all
  end

  def show
    @report = Loaders::LoadReport.find(params[:id])
    @images = Loaders::ImageReport.where(load_report_id:"#{@report.id}").find_all
    @user = User.find_by_nuid(@report.nuid)
    puts @user
    render 'loaders/show', locals: {images: @images, user: @user}
  end

  protected
    def process_file(file, parent, copyright)
      if virus_check(file) == 0
        tempdir = Rails.root.join("tmp")
        uniq_hsh = Digest::MD5.hexdigest("#{file.original_filename}")[0,2]
        file_name = "#{Time.now.to_i.to_s}-#{uniq_hsh}"
        new_path = tempdir.join(file_name).to_s
        new_file = "#{new_path}.zip"
        FileUtils.mv(file.tempfile.path, new_file)
        #if zip
        if extract_mime_type(new_file) == 'application/zip'
          # send to job
          Cerberus::Application::Queue.push(ProcessZipJob.new("marcom", new_file.to_s, parent, copyright, current_user))
          flash[:notice] = "Your file has been submitted and is now being processed. Check back soon for a load report."
          redirect_to my_loaders_path
        else
          #error out
          FileUtils.rm(new_file)
          flash[:error] = "The file you uploaded was not a zipfile. Please try again."
          redirect_to my_loaders_path
        end
      else
        flash[:error] = "Error creating file."
        redirect_to my_loaders_path
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
