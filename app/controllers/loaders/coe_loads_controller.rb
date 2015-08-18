# -*- coding: utf-8 -*-

class Loaders::CoeLoadsController < ApplicationController
  include Cerberus::Controller
  include MimeHelper

  before_filter :authenticate_user!
  before_filter :verify_group

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render_404(ActiveRecord::RecordNotFound.new) and return
  end

  def new
    @parent = Collection.find("neu:5m60qz05t")
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
    @loader_name = t('drs.loaders.coe.long_name')
    @loader_short_name = t('drs.loaders.coe.short_name')
    @page_title = @loader_name + " Loader"
    render 'loaders/new', locals: { collections_options: @collections_options}
  end

  def create
    @copyright = t('drs.loaders.coe.copyright')
    permissions = {"edit" => ["northeastern:drs:college_of_engineering:deans_office", "northeastern:drs:repository:staff"]}
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
        process_file(file, parent, @copyright, permissions)
      end
    rescue => exception
      logger.error "CoeLoadsController::create rescued #{exception.class}\n\t#{exception.to_s}\n #{exception.backtrace.join("\n")}\n\n"
      email_handled_exception(exception)
      json_error "Error occurred while creating file."
    ensure
      # remove the tempfile (only if it is a temp file)
      file.tempfile.delete if file.respond_to?(:tempfile)
    end
  end

  def show
    @report = Loaders::LoadReport.find(params[:id])
    @images = Loaders::ImageReport.where(load_report_id:"#{@report.id}").find_all
    @user = User.find_by_nuid(@report.nuid)
    @page_title = @report.loader_name + " Load into " + Collection.find(@report.collection).title
    render 'loaders/show', locals: {images: @images, user: @user}
  end

  def show_iptc
    @image = Loaders::ImageReport.find(params[:id])
    @load = Loaders::LoadReport.find(@image.load_report_id)
    @page_title = @image.original_file
    render 'loaders/iptc', locals: {image: @image, load: @load}
  end

  protected
    def process_file(file, parent, copyright, permissions)
      @loader_name = t('drs.loaders.coe.long_name')
      if virus_check(file) == 0
        if Rails.env.production?
          tempdir = Pathname.new("/tmp/DRStmp/")
        else
          tempdir = Rails.root.join("tmp")
        end

        uniq_hsh = Digest::MD5.hexdigest("#{file.original_filename}")[0,2]
        file_name = "#{Time.now.to_i.to_s}-#{uniq_hsh}"
        new_path = tempdir.join(file_name).to_s
        new_file = "#{new_path}.zip"
        FileUtils.mv(file.tempfile.path, new_file)
        #if zip
        if extract_mime_type(new_file) == 'application/zip'
          # send to job
          Cerberus::Application::Queue.push(ProcessZipJob.new(@loader_name, new_file.to_s, parent, copyright, current_user, permissions))
          session[:flash_success] = "Your file has been submitted and is now being processed. You will receive an email when the load is complete."
        else
          #error out
          FileUtils.rm(new_file)
          session[:flash_error] = 'The file you uploaded was not a zipfile. Please try again.';
        end
      else
        session[:flash_error] = 'Error creating file.';
      end
      render :nothing => true
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
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.coe_loader?
    end
end
