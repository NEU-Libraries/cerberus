class Loaders::LoadsController < ApplicationController
  include Cerberus::Controller
  include MimeHelper
  include ZipHelper

  before_filter :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render_404(ActiveRecord::RecordNotFound.new, request.fullpath) and return
  end

  def process_new(parent, short_name)
    @parent = ActiveFedora::Base.find("#{parent}", cast: true)
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
    @loader_name = t('loaders.'+short_name+'.long_name')
    @loader_short_name = short_name
    @page_title = @loader_name + " Loader"
    render 'loaders/new', locals: { collections_options: @collections_options}
  end

  def process_create(short_name, controller_name, existing_files=false, derivatives=false)
    @copyright = t('loaders.'+short_name+'.copyright')
    begin
      # check error condition No files
      if !params.has_key?(:file)
        msg = "Error! No file to save"
        session[:flash_error] = msg
        render :json => [{error: msg}].to_json and return
      end
      file = params[:file]
      parent = params[:parent]
      if !file
        msg = "Error! No file for upload"
        session[:flash_error] = msg
        render :json => [{error: msg}].to_json and return
      elsif parent.blank? && existing_files == false
        msg = "No collection was selected."
        session[:flash_error] = msg
        render :json => [{error: msg}].to_json and return
      elsif existing_files == false && !parent.start_with?("neu:")
        msg = "No collection exists with the value entered: \"#{parent}\"."
        session[:flash_error] = msg
        render :json => [{error: msg}].to_json and return
      elsif (empty_file?(file))
        msg = "Error! Zero Length File!"
        session[:flash_error] = msg
        render :json => [{error: msg}].to_json and return
      elsif (!terms_accepted?)
        msg = "You must accept the terms of service!"
        session[:flash_error] = msg
        render :json => [{error: msg}].to_json and return
      elsif (File.extname(file.tempfile.path) == ".zip") && ((File.size(file.tempfile).to_f / 1024000).round(2) > 4000) #4000 is 4000MB
        msg = "The file you chose is larger than 4000MB. Please contact DRS staff for help uploading files larger than 4000MB."
        session[:flash_error] = msg
        render :json => [{error: msg}].to_json and return
      elsif (File.extname(file.tempfile.path) != (".zip" || ".tar.gz"))
        msg = "The file must be of type zip or gzip. The relevant extensions are .zip and .tar.gz respectively."
        session[:flash_error] = msg
        render :json => [{error: msg}].to_json and return
      elsif existing_files == false && ActiveFedora::Base.find(parent, cast: true).class != Collection
        msg = "PID \"#{parent}\" entered does not correspond to a Collection. The object returned was a #{ActiveFedora::Base.find(parent, cast: true).class}"
        session[:flash_error] = msg
        render :json => [{error: msg}].to_json and return
      else
        if existing_files == false
          collection = Collection.find(parent) #do this to catch any other health issues with the parent
        end
        process_file(file, parent, @copyright, short_name, existing_files, derivatives)
      end
    rescue => exception
      logger.error controller_name+"::create rescued #{exception.class}\n\t#{exception.to_s}\n #{exception.backtrace.join("\n")}\n\n"
      email_handled_exception(exception)
      msg = "Error occurred while creating file. Error received was: #{exception.to_s}"
      session[:flash_error] = msg
      render :json => [{error: msg}].to_json and return
    ensure
      # remove the tempfile (only if it is a temp file)
      file.tempfile.delete if file.respond_to?(:tempfile)
    end
  end

  def show
    @report = Loaders::LoadReport.find(params[:id])
    image_count = Loaders::ItemReport.where(load_report_id:"#{@report.id}").count
    if params[:per_page]
      per_page = params[:per_page] == "All" ? image_count : params[:per_page]
    else
      per_page = 50
    end
    @images = Loaders::ItemReport.where(load_report_id:"#{@report.id}").paginate(:page => params[:page], :per_page => per_page)
    @user = User.find_by_nuid(@report.nuid)
    if @report.collection
      @collection = Collection.find(@report.collection)
      @page_title = @report.loader_name + " Load into " + @collection.title
    else
      @page_title = @report.loader_name + " Load"
      @collection = @collection_link = nil
    end
    if session[:flash_error]
      flash[:error] = session[:flash_error]
      session[:flash_error] = nil
    end
    if session[:flash_success]
      flash[:notice] = session[:flash_success]
      session[:flash_success] = nil
    end
    respond_to do |format|
      format.js {
        render 'loaders/show', locals: {images: @images, user: @user}
      }
      format.html {
        render 'loaders/show', locals: {images: @images, user: @user}
      }
    end
  end

  def show_iptc
    @image = Loaders::ItemReport.find(params[:id])
    @load = Loaders::LoadReport.find(@image.load_report_id)
    @page_title = @image.original_file
    render 'loaders/iptc', locals: {image: @image, load: @load}
  end

  protected
    def process_file(file, parent, copyright, short_name, existing_files, derivatives=false)
      @loader_name = t('loaders.'+short_name+'.long_name')
      if virus_check(file) == 0
        tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
        uniq_hsh = Digest::MD5.hexdigest("#{file.original_filename}")[0,2]
        file_name = "#{Time.now.to_f.to_s.gsub!('.','-')}-#{uniq_hsh}"
        new_path = tempdir.join(file_name).to_s
        new_file = "#{new_path}#{File.extname(file.original_filename)}"
        FileUtils.mv(file.tempfile.path, new_file)
        #if zip
        if (extract_mime_type(new_file) == 'application/zip') || (extract_mime_type(new_file) == 'application/x-tar')
          begin
            @report_id = nil
            if short_name == "spreadsheet"
              #mods spreadsheet job
              spreadsheet_file_path = unzip(new_file, new_path)
              @report_id = Loaders::LoadReport.create_from_strings(current_user, @loader_name, parent)
              ProcessModsZipJob.new(@loader_name, spreadsheet_file_path, parent, copyright, current_user, @report_id, existing_files, nil, true).run
              load_report = Loaders::LoadReport.find(@report_id)
              session[:flash_success] = "Your file has been submitted and is now being processed. You will receive an email when the load is complete."
              if !load_report.comparison_file_pid.blank?
                render :json => {report_id: @report_id, comparison_file_pid: load_report.comparison_file_pid}.to_json and return
              elsif !load_report.preview_file_pid.blank?
                render :json => {report_id: @report_id, preview_file_pid: load_report.preview_file_pid}.to_json and return
              end
            elsif short_name == "xml"
              spreadsheet_file_path = unzip(new_file, new_path)
              @report_id = Loaders::LoadReport.create_from_strings(current_user, @loader_name, parent)
              ProcessXmlZipJob.new(@loader_name, spreadsheet_file_path, parent, copyright, current_user, @report_id, existing_files, nil, true).run
              load_report = Loaders::LoadReport.find(@report_id)
              session[:flash_success] = "Your file has been submitted and is now being processed. You will receive an email when the load is complete."
              if !load_report.comparison_file_pid.blank?
                render :json => {report_id: @report_id, comparison_file_pid: load_report.comparison_file_pid}.to_json and return
              elsif !load_report.preview_file_pid.blank?
                render :json => {report_id: @report_id, preview_file_pid: load_report.preview_file_pid}.to_json and return
              end
            else
              # send to iptc job
              @report_id = Loaders::LoadReport.create_from_strings(current_user, @loader_name, parent)
              Cerberus::Application::Queue.push(ProcessIptcZipJob.new(@loader_name, new_file.to_s, parent, copyright, current_user, @report_id,  derivatives))
              session[:flash_success] = "Your file has been submitted and is now being processed. You will receive an email when the load is complete."
              render :json => {report_id: @report_id}.to_json and return
            end
          rescue => exception
            logger.error controller_name+"::create rescued #{exception.class}\n\t#{exception.to_s}\n #{exception.backtrace.join("\n")}\n\n"
            email_handled_exception(exception)
            if (exception.to_s.include?("Nokogiri") || exception.to_s.include?("MissingMetadata") || exception.to_s.include?("XmlEncodingError") || exception.to_s.include?("MalformedDate")) && (short_name == "spreadsheet" || short_name == "xml")
              error_msg = "There was an error in displaying the Preview screen. Please <a href='/loaders/#{short_name}/report/#{@report_id}'>check the load report</a> for more information."
              session[:flash_error] = error_msg
            else
              session[:flash_error] = exception.to_s
            end
            json_error exception.to_s
          end
        else
          FileUtils.rm(new_file)
          error = "The file uploaded was not a zip file."
          session[:flash_error] = error
          json_error error
        end
      else
        error = "Error processing file."
        session[:flash_error] = error
        json_error error
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

    def unzip(file, dir_path)
      spreadsheet_file_path = ""
      FileUtils.mkdir(dir_path) unless File.exists? dir_path

      # Extract load zip
      file_list = safe_unzip(file, dir_path)

      # Find the spreadsheet
      xlsx_array = Dir.glob("#{dir_path}/manifest.xlsx")

      if xlsx_array.length > 1
        raise Exceptions::MultipleSpreadsheetError
      elsif xlsx_array.length == 0
        raise Exceptions::NoSpreadsheetError
      end

      uniq_hsh = Digest::MD5.hexdigest("#{File.basename(xlsx_array.first)}")[0,2]
      clean_path = dir_path+"/#{Time.now.to_f.to_s.gsub!('.','-')}-#{uniq_hsh}.xlsx"
      FileUtils.mv(xlsx_array.first, clean_path)
      spreadsheet_file_path = clean_path
      FileUtils.rm(file)
      return spreadsheet_file_path
    end
end
