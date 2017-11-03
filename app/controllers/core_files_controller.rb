require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'
require 'stanford-mods'
require 'will_paginate/array'

# -*- coding: utf-8 -*-
class CoreFilesController < ApplicationController
  include Cerberus::Controller
  include Cerberus::TempFileStorage
  include Cerberus::ThumbnailCreation
  include Cerberus::ControllerHelpers::EditableObjects
  include Cerberus::ControllerHelpers::ViewLogger
  include Cerberus::ControllerHelpers::PermissionsCheck

  include ModsDisplay::ControllerExtension
  include ApplicationHelper
  include XmlValidator
  include HandleHelper
  include MimeHelper
  include ChecksumHelper
  include SentinelHelper

  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller

  before_filter :authenticate_user!, except: [:oai_thumbnail, :show, :get_associated_files, :get_page_file, :log_stream, :fulltext, :audio]

  skip_before_filter :normalize_identifier
  skip_load_and_authorize_resource only: [:provide_metadata,
                                          :rescue_incomplete_file,
                                          :destroy_incomplete_file,
                                          :process_metadata,
                                          :edit,
                                          :update,
                                          :destroy]

  before_filter :can_edit_parent_or_proxy_upload?, only: [:new, :create, :destroy_incomplete_file]

  before_filter :can_read?, only: [:show, :get_associated_files, :get_page_file]
  before_filter :can_edit?, only: [:edit, :update]
  before_filter :complete?, only: [:edit, :update]

  before_filter :valid_form_permissions?, only: [:process_metadata, :update]

  before_filter :verify_staff_or_beta, only: [:validate_xml, :edit_xml]

  before_filter :verify_admin, only: [:reindex, :create_attached_file, :new_attached_file, :provide_file_metadata, :process_file_metadata, :destroy_content_object, :associate, :disassociate]

  self.solr_search_params_logic += [:add_access_controls_to_solr_params]

  rescue_from Exceptions::NoParentFoundError, with: :no_parent_rescue
  rescue_from Exceptions::GroupPermissionsError, with: :group_permission_rescue

  rescue_from ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Object"
    email_handled_exception(exception)
    render_404(ActiveFedora::ObjectNotFoundError.new, request.fullpath) and return
  end

  rescue_from Exceptions::SearchResultTypeError do |exception|
    # No longer emailing this error - it's always Pat debugging
    render_404(ActiveFedora::ObjectNotFoundError.new, request.fullpath) and return
  end

  configure_mods_display do
    access_condition do
      display!
    end
    subject do
      delimiter " -- "
    end
    abstract do
      delimiter "<br><br>"
    end
  end

  def reindex
    pid = params[:id]

    # Invalidate cache
    Rails.cache.delete_matched("/mods/#{pid}*")
    Rails.cache.delete_matched("/darwin/#{pid}*")

    # Update solr doc
    CoreFile.find(pid).update_index

    flash[:notice] = "File reindexed."
    redirect_to core_file_path(pid) and return
    # render :nothing => true
  end

  def fulltext
    doc = fetch_solr_document
    cf = CoreFile.find(doc.pid)
    if !(cf.under_embargo?(current_user))
      asset = PdfFile.find(doc.canonical_object.first.pid)
      if !asset.blank?
        log_action('download', 'COMPLETE', asset.pid)
        file_name = "neu_#{asset.pid.split(":").last}.#{extract_extension(asset.properties.mime_type.first, File.extname(asset.original_filename || "").delete!("."))}"
        send_file asset.fedora_file_path, :filename =>  file_name, :type => asset.mime_type || extract_mime_type(asset.fedora_file_path), :disposition => 'inline'
      end
    else
      render_403 and return
    end
  end

  def audio
    # 1142 fix
    doc = fetch_solr_document
    asset = AudioFile.find(doc.canonical_object.first.pid)
    if doc.public? && !asset.blank?
      log_action('download', 'COMPLETE', asset.pid)
      file_name = "neu_#{asset.pid.split(":").last}.#{extract_extension(asset.properties.mime_type.first, File.extname(asset.original_filename || "").delete!("."))}"
      send_file asset.fedora_file_path, :range => true, :filename => file_name, :type => asset.mime_type || extract_mime_type(asset.fedora_file_path), :disposition => 'inline'
    else
      render_404(ActiveFedora::ObjectNotFoundError.new, request.fullpath) and return
    end
  end

  def oai_thumbnail
    # For the purposes of OAI consumption, we'll reduce our multiple thumbnails to a best-available
    # option, with a singular path which doesn't require relationship knowledge, or external pid
    # understanding.

    # This will be restricted per request to the largest available square (aspect-ratio constrained)
    # thumbnail, which at the time of coding this, is thumbnail_3 or lower (340 x 340)
    @core_file = fetch_solr_document

    thumbnail_list = @core_file.thumbnail_list
    if thumbnail_list.length > 2
      redirect_to thumbnail_list[2]
    elsif thumbnail_list.length > 1
      redirect_to thumbnail_list[1]
    elsif thumbnail_list.length == 1
      redirect_to thumbnail_list[0]
    else
      # No thumbnail
      render_404(ActiveFedora::ObjectNotFoundError.new, request.fullpath) and return
    end
  end

  def destroy_incomplete_file
    @core_file = fetch_solr_document

    if @core_file.in_progress? && (@core_file.klass == "CoreFile")
      # User completed second screen, so they most likely went back accidentally
      # Do nothing
    elsif @core_file.incomplete?
      @core_file = CoreFile.find(@core_file.pid)
      @core_file.destroy

      respond_to do |format|
        format.html{
            flash[:notice] = "Temporary file destroyed"
            redirect_to(root_path) and return
          }
        format.js   { render :nothing => true }
      end
    end

    render :nothing => true
  end

  def destroy_content_object
    @content_object = fetch_solr_document({:id=>params[:content_object_id]})
    klass = @content_object.klass.constantize
    @content_object = klass.find(params[:content_object_id])
    if File.exists?(@content_object.tmp_path)
      FileUtils.rm(@content_object.tmp_path)
    end
    @content_object.destroy
    respond_to do |format|
      format.html{
          flash[:notice] = "File destroyed"
          redirect_to(root_path) and return
        }
      format.js   { render :nothing => true }
    end

    render :nothing => true
  end

  def provide_metadata
    @core_file = CoreFile.find(params[:id])
    @collection = @core_file.parent

    if !@collection.nil? && !@collection.smart_collection_type.blank? && @collection.smart_collection_type != "miscellany"
      flash[:alert] = "Note: You are depositing this file in a Smart Collection. Library staff will review permissions and enhance metadata as needed."
    end

    @page_title = "Provide Upload Metadata"
  end

  def provide_file_metadata
    @core_file = CoreFile.find(params[:id])
    klass = class_for_attached_file(@core_file)
    @content_object = klass.find(params[:content_object_id])
    @page_title = "Provide File Metadata"
    if session[:flash_error]
      flash[:error] = session[:flash_error]
      session[:flash_error] = nil
    end
    if session[:flash_success]
      flash[:notice] = session[:flash_success]
      session[:flash_success] = nil
    end
  end

  # routed to files/rescue_incomplete_files
  # page for allowing users to either permanently delete or apply metadata to
  # files abandoned without completing step two of the upload process.
  def rescue_incomplete_file
    if params["abandoned"]
      @incomplete = fetch_solr_document(id: params["abandoned"])
    else
      file = CoreFile.abandoned_for_nuid(current_user.nuid).first
      @incomplete = file
    end

    @page_title = "Rescue abandoned files"
  end

  def process_metadata
    @core_file = CoreFile.find(params[:id])

    # if no title or keyword, send them back. Only God knows what they did to the form...
    # fix for #671
    if !title_and_keyword?
      redirect_to files_provide_metadata_path(@core_file.pid) and return
    end

    # Moved to later in process to prevent accidental deletion
    @core_file.tag_as_in_progress
    @core_file.save!
    @core_file.reload

    if @core_file.proxy_uploader.present?
      depositor_nuid = @core_file.proxy_uploader
      proxy_nuid     = current_user.nuid
    else
      depositor_nuid = current_user.nuid
      proxy_nuid     = nil
    end

    update_metadata if params[:core_file]
    max = session[:slider_max]

    # Process Thumbnail
    if params[:poster]
      file = params[:poster]
      poster_path = move_file_to_tmp(file)
      mime = extract_mime_type(poster_path)
      type = mime.split("/").first.strip
      if type == 'image'
        if params[:caption]
          captions_file = params[:caption]
          captions_path = move_file_to_tmp(captions_file)
          mime = extract_mime_type(captions_path)
          type = mime.split("/").first.strip
          if type == "text"
            Cerberus::Application::Queue.push(ContentCreationJob.new(@core_file.pid, @core_file.tmp_path, @core_file.original_filename, poster_path, captions_path))
          else
            flash[:error] = "Error! The captions attached is not a text file."
            redirect_to files_provide_metadata_path(@core_file.pid) and return
          end
        else
          Cerberus::Application::Queue.push(ContentCreationJob.new(@core_file.pid, @core_file.tmp_path, @core_file.original_filename, poster_path))
        end
      else
        flash[:error] = "Error! The thumbnail attached is not an image."
        redirect_to files_provide_metadata_path(@core_file.pid) and return
      end
    elsif !max.nil?
      s = params[:small_image_size].to_f / max.to_f
      m = params[:medium_image_size].to_f / max.to_f
      l = params[:large_image_size].to_f / max.to_f

      Cerberus::Application::Queue.push(ContentCreationJob.new(@core_file.pid, @core_file.tmp_path, @core_file.original_filename, nil, nil, s, m, l))
    else
      Cerberus::Application::Queue.push(ContentCreationJob.new(@core_file.pid, @core_file.tmp_path, @core_file.original_filename))
    end

    # Add drs staff to permissions for #608
    @core_file.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")

    if params[:stream_only]
      @core_file.tag_as_stream_only
      @core_file.save!
      @core_file.reload
    end

    if @core_file.save!
      if params[:core_file]
        UploadAlert.create_from_core_file(@core_file, :create, "single", current_user)
      end
    end

    redirect_to core_file_path(@core_file.pid) + '#no-back'
  end

  def process_file_metadata
    @core_file = CoreFile.find(params[:id])
    klass = class_for_attached_file(@core_file)
    @content_object = klass.find(params[:content_object_id])
    Cerberus::Application::Queue.push(ContentObjectCreationJob.new(@core_file.pid, @content_object.tmp_path, @content_object.pid, @content_object.original_filename, params[:content_object][:permissions], params[:content_object][:mass_permissions]))
    UploadAlert.create_from_core_file(@core_file, :update, "content object", current_user)
    flash[:notice] = "Your file is being processed. The file's checksum is #{@content_object.properties.md5_checksum.first}"
    redirect_to core_file_path(@core_file.pid) + '#no-back'
  end

  # routed to /files/:id
  def show
    @core_file = fetch_solr_document
    @mods = fetch_mods
    @darwin = fetch_darwin

    begin
      @parent = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{@core_file.parent}\"").first)
    rescue => exception
      # At this stage most likely a supplemental file
      if @core_file.supplemental_material_for.blank?
        email_handled_exception(exception)
      end
    end

    @thumbs = @core_file.thumbnail_list
    @page_title = "#{@core_file.non_sort} #{@core_file.title}"

    log_action("view", "COMPLETE")

    if @core_file.in_progress?
      flash[:notice] = 'Your files are being processed by ' + t('drs.product_name.short') + ' in the background. The metadata and access controls you specified are being applied. Files will be marked <span class="label label-warning" title="Updating">Updating</span> until this process is complete (shouldn\'t take too long, hang in there!).'
    end

    if ((Time.now.utc - DateTime.parse(@core_file.updated_at)) / 1.hour) < 1
      response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
    end

    respond_to :html
  end

  def create
    begin
      # bounce them if no parent is set
      return json_error("Error! No parent set") if !params.has_key?(:collection_id)

      # check error condition No files
      return json_error("Error! No file to save") if !params.has_key?(:file)

      file = params[:file]
      if !file
        session[:flash_error] = "Error! No file for upload"
        render :json => { url: session[:previous_url] }
      elsif (empty_file?(file))
        session[:flash_error] = "Error! Zero Length File!"
        render :json => { url: session[:previous_url] }
      elsif (!(current_user.admin_group? || current_user.admin?) && current_user.repo_staff? && (File.size(file.tempfile).to_f / 1024000).round(2) > 10000) #10000 is 10000MB
        session[:flash_error] = "The file you chose is larger than 10,000MB. Please contact DRS staff for help uploading files larger than 10,000MB."
        render :json => { url: session[:previous_url] }
      elsif (!(current_user.admin_group? || current_user.admin?) && !current_user.repo_staff? && (File.size(file.tempfile).to_f / 1024000).round(2) > 1000) #1000 is 1000MB
        session[:flash_error] = "The file you chose is larger than 1000MB. Please contact DRS staff for help uploading files larger than 1000MB."
        render :json => { url: session[:previous_url] }
      elsif (!terms_accepted?)
        session[:flash_error] = "You must accept the terms of service!"
        render :json => { url: session[:previous_url] }
      elsif current_user.proxy_staff? && params[:upload_type].nil?
        session[:flash_error] = "You must select whether this is a proxy or personal upload"
        render :json => { url: session[:previous_url] }
      else
        process_file(file)
      end
    rescue => exception
      logger.error "CoreFilesController::create rescued #{exception.class}\n\t#{exception.to_s}\n #{exception.backtrace.join("\n")}\n\n"
      email_handled_exception(exception)
      json_error "Error occurred while creating file."
    ensure
      # remove the tempfile (only if it is a temp file)
      file.tempfile.delete if file.respond_to?(:tempfile)
    end
  end

  def create_attached_file
    begin
      @core_file = CoreFile.find(params[:id])
      # check error condition No files
      return json_error("Error! No file to save") if !params.has_key?(:file)

      file = params[:file]
      if !file
        session[:flash_error] = "Error! No file for upload"
        render :json => { url: session[:previous_url] }
      elsif (empty_file?(file))
        session[:flash_error] = "Error! Zero Length File!"
        render :json => { url: session[:previous_url] }
      elsif (!terms_accepted?)
        session[:flash_error] = "You must accept the terms of service!"
        render :json => { url: session[:previous_url] }
      elsif current_user.proxy_staff? && params[:upload_type].nil?
        session[:flash_error] = "You must select whether this is a proxy or personal upload"
        render :json => { url: session[:previous_url] }
      elsif @core_file.canonical_class_from_file(file) != @core_file.canonical_class
        session[:flash_error] = "You must upload an #{t("drs.display_labels.#{@core_file.canonical_class}.short")} file."
        render :json => { url: session[:previous_url] }
      elsif @core_file.has_master_object?
        session[:flash_error] = "This file already has a master file."
        render :json => { url: session[:previous_url] }
      else
        if virus_check(file) == 0
          new_path = move_file_to_tmp(file)
          klass = class_for_attached_file(@core_file)
          content_object = klass.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
          content_object.tmp_path = new_path
          checksum = new_checksum(new_path)
          if !params[:checksum].blank? && params[:checksum] != checksum
            session[:flash_error] = "The submitted MD5 hash value does not match the MD5 generated during ingest."
          end
          content_object.properties.md5_checksum = checksum
          content_object.original_filename = file.original_filename
          if current_user.proxy_staff? && params[:upload_type] == "proxy"
            content_object.depositor = @core_file.depositor
            content_object.proxy_uploader = current_user.nuid
          else
            content_object.depositor = current_user.nuid
          end
          content_object.save!
          render json: { url: files_provide_file_metadata_path(@core_file.pid, content_object.pid)}
        else
          session[:flash_error] = "The file attached did not pass virus check."
          render :json => { url: session[:previous_url] }
        end
      end
    rescue => exception
      logger.error "CoreFilesController::create rescued #{exception.class}\n\t#{exception.to_s}\n #{exception.backtrace.join("\n")}\n\n"
      email_handled_exception(exception)
      json_error "Error occurred while creating file."
    ensure
      # remove the tempfile (only if it is a temp file)
      # file.tempfile.delete if file.respond_to?(:tempfile)
    end
  end

  # routed to /files/new
  def new
    @page_title = "Upload New Files"

    abandoned_files = CoreFile.abandoned_for_nuid(current_user.nuid)

    if abandoned_files.any?
      # Delete abandoned files that no longer have their file available
      # either failed, and can't complete, or fell foul of the 6 hour window
      abandoned_files.delete_if do |doc|
        begin
          cf = CoreFile.find(doc.pid)
          if !(File.exists?(cf.tmp_path))
            cf.destroy
            return true
          end
        rescue Exception => error
          return true
        end
        false
      end
    end

    if abandoned_files.any?
      file = abandoned_files.first
      redirect_to rescue_incomplete_file_path("abandoned" => file.pid)
      return
    end

    if session[:flash_error]
      flash[:error] = session[:flash_error]
      session[:flash_error] = nil
    end
    if session[:flash_success]
      flash[:notice] = session[:flash_success]
      session[:flash_success] = nil
    end

    @core_file = ::CoreFile.new
  end

  def new_attached_file
    @core_file = fetch_solr_document

    if session[:flash_error]
      flash[:error] = session[:flash_error]
      session[:flash_error] = nil
    end
    if session[:flash_success]
      flash[:notice] = session[:flash_success]
      session[:flash_success] = nil
    end

    render 'new_attached_file'
  end

  def edit
    @core_file = CoreFile.find(params[:id])
    @page_title = "Edit #{@core_file.title}"
  end

  def mods_history_list
    @core_file = CoreFile.find(params[:id])
    @mods_changes = Hash.new

    @core_file.mods.versions.each_with_index do |v, i|
      date = v.createDate.localtime.to_s

      a = v.content

      if !@core_file.mods.versions[i + 1].blank?
        b = @core_file.mods.versions[i + 1].content
      else
        b = ""
      end

      distance = DamerauLevenshtein.distance(a, b, 1, 10000)

      @mods_changes[date] = distance.to_s
    end

  end

  def mods_history
    @core_file = CoreFile.find(params[:id])
    @mods_pages = @core_file.mods.versions.paginate(:page => params[:page], :per_page => 1)

    if params[:page].to_i != @core_file.mods.versions.length
      mods_a = Nokogiri::XML(@core_file.mods.versions[params[:page].to_i].content).to_s
    else
      mods_a = ""
    end

    mods_b = Nokogiri::XML(@core_file.mods.versions[params[:page].to_i - 1].content).to_s

    @diff = mods_diff(mods_a, mods_b)
    @diff_css = Diffy::CSS
  end

  def edit_xml
    @core_file = CoreFile.find(params[:id])

    if params[:version]
      @mods = @core_file.mods.versions[params[:version].to_i].content
      flash[:notice] =  "XML Editor has been populated with MODS from #{@core_file.mods.versions[params[:version].to_i].createDate.localtime.to_s}"
    else
      # Purge bad keyword template mapping
      xml = Nokogiri::XML(@core_file.mods.content)
      xml.search("//mods:keyword").each do |node|
        node.remove
      end

      @core_file.mods.content = xml.to_s
      @core_file.save!

      @mods = @core_file.mods.content
    end

    @page_title = "Edit #{@core_file.title}'s xml"
    md = CoreFile.new
    md.mods.content = @mods
    @mods_html = render_mods_display(md).to_html.html_safe
    render :template => 'core_files/ace_xml_editor'
  end

  def validate_xml
    # Unicode replace fancy punctuation
    # raw_xml = CGI.unescapeHTML(Unidecoder.decode(params[:raw_xml].first))
    raw_xml = xml_decode(params[:raw_xml].first)

    @result = xml_valid?(raw_xml, true)

    if !@result[:errors].blank?
      # Formatting error array for template
      error_list = "<h4 class='xml-error'>Invalid XML provided</h4></br> "
      @result[:errors].each do |entry|
        error_list = error_list.concat(CGI::escapeHTML("#{entry.class.to_s}: #{entry}") + " </br></br> ")
      end
      @result = error_list
    elsif !params[:commit].blank? && params[:commit] == "Save"
      if !@result[:mods_html].blank?
        # Valid, and ready to save
        @core_file = CoreFile.find(params[:id])

        # Invalidate cache
        Rails.cache.delete_matched("/mods/#{@core_file.pid}*")
        Rails.cache.delete_matched("/darwin/#{@core_file.pid}*")

        # Email the metadata changes
        new_doc = Nokogiri::XML(raw_xml)
        old_doc = Nokogiri::XML(@core_file.mods.content)

        XmlAlert.create_from_strings(@core_file, current_user, old_doc.to_s, new_doc.to_s)

        @core_file.mods.content = raw_xml
        @core_file.save!
        @core_file.match_dc_to_mods

        render js: "window.location = '#{core_file_path(@core_file.pid)}'" and return
      else
        # Catch all - fixes undefined method `html_safe' for {:errors=>[], :mods_html=>""}:Hash
        @result = error_list = "<h4 class='xml-error'>Invalid XML provided</h4></br>"
      end
    else
      @result = @result[:mods_html]
    end

    respond_to do |format|
      format.js
    end
  end

  def update
    @core_file = CoreFile.find(params[:id])

    # Invalidate cache
    Rails.cache.delete_matched("/mods/#{@core_file.pid}*")
    Rails.cache.delete_matched("/darwin/#{@core_file.pid}*")

    # if no title or keyword, send them back. Only God knows what they did to the form...
    # fix for #671
    if !title_and_keyword?
      redirect_to edit_core_file_path(@core_file.pid) and return
    end

    # Process Thumbnail
    if params[:replacement_thumbnail]
      file = params[:replacement_thumbnail]
      thumb_path = move_file_to_tmp(file)
      mime = extract_mime_type(thumb_path)
      type = mime.split("/").first.strip
      if type == 'image'
        # Destroy old thumbnail
        if @core_file.thumbnail != false
          ImageThumbnailFile.find(@core_file.thumbnail.pid).destroy
        end

        if @core_file.canonical_class == "VideoFile" || @core_file.canonical_class == "AudioFile"
          # Destroy old poster
          @core_file.content_objects.each do |co|
            if co.class == ImageMasterFile
              co.destroy
            end
          end

          poster_object = ImageMasterFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint), core_record: @core_file)

          File.open(thumb_path) do |poster_contents|
            poster_object.add_file(poster_contents, 'content', "poster#{File.extname(thumb_path)}")
            poster_object.rightsMetadata.content = @core_file.rightsMetadata.content
            poster_object.save!
          end

          DerivativeCreator.new(poster_object.pid).generate_derivatives
          @core_file.update_index
        else
          # Create thumbnail obj
          thumb = ImageThumbnailFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))

          thumb.depositor              = @core_file.depositor
          thumb.core_record            = @core_file
          thumb.rightsMetadata.content = @core_file.rightsMetadata.content
          thumb.save!

          create_all_thumbnail_sizes(thumb_path, thumb.pid)

          thumbnail_list = []

          thumb.reload
          if thumb.datastreams["thumbnail_1"].content != nil
            for i in 1..5 do
              thumbnail_list << "/downloads/#{thumb.pid}?datastream_id=thumbnail_#{i}"
            end
          end

          @core_file.thumbnail_list = thumbnail_list
          @core_file.save!
        end
      else
        flash[:error] = "Error! The thumbnail attached is not an image."
        redirect_to files_provide_metadata_path(@core_file.pid) and return
      end
    end

    # process caption file
    if params[:caption]
      if @core_file.canonical_class == "VideoFile" || @core_file.canonical_class == "AudioFile"
        # Destroy old caption file
        @core_file.content_objects.each do |co|
          if co.class == TextFile
            co.destroy
          end
        end

        file = params[:caption]
        captions_path = move_file_to_tmp(file)
        mime = extract_mime_type(captions_path)
        type = mime.split("/").first.strip
        sentinel = @core_file.parent.sentinel

        if type == "text"
          caption_object = TextFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint), core_record: @core_file)
          File.open(captions_path) do |caption_contents|
            caption_object.add_file(caption_contents, 'content', "caption#{File.extname(captions_path)}")
            caption_object.rightsMetadata.content = @core_file.rightsMetadata.content #apply core_file permissions
            # and sentinel permissions in case they exist
            if sentinel && !sentinel.send(sentinel_class_to_symbol("TextFile")).blank?
              # set content object to sentinel value
              # convert klass to string to send to sentinel to get rights
              caption_object.permissions = sentinel.send(sentinel_class_to_symbol("TextFile"))["permissions"]
              caption_object.mass_permissions = sentinel.send(sentinel_class_to_symbol("TextFile"))["mass_permissions"]
            end
            caption_object.save!
          end
          @core_file.update_index
        else
          flash[:error] = "Error! The captions attached is not a text file."
          redirect_to files_provide_metadata_path(@core_file.pid) and return
        end
      end
    end

    # only update metadata if there is a core_file object which is not the case for version updates
    update_metadata if params[:core_file]

    #always save the file so the new version or metadata gets recorded
    if @core_file.save
      if params[:core_file]
        UploadAlert.create_from_core_file(@core_file, :update, "single", current_user)
      end

      # If this change updated metadata, propagate the change outwards to
      # all content objects
      if params[:core_file]
        q = Cerberus::Application::Queue
        q.push(PropagateCoreMetadataChangeJob.new(@core_file.pid))
      end
    end

    redirect_to(@core_file)
  end

  def log_stream
    log_action("stream", "COMPLETE")
    render :nothing => true
  end

  def tombstone
    core_file = CoreFile.find(params[:id])
    title = core_file.title
    collection = core_file.parent.id
    reason = params[:reason]
    if reason != ""
      core_file.tombstone(reason + " " + DateTime.now.strftime("%F"))
    else
      core_file.tombstone
    end
    redirect_to collection_path(id: collection), notice: "The file '#{title}' has been tombstoned"
  end

  def request_tombstone
    core_file = CoreFile.find(params[:id])
    title = core_file.title
    collection = core_file.parent.id
    user = current_user
    reason = params[:reason]
    DeleteMailer.delete_alert(core_file, reason, user).deliver!
    flash[:notice] = "Your request has been received and will be processed soon."
    redirect_to core_file and return
  end

  def request_move
    core_file = CoreFile.find(params[:id])
    title = core_file.title
    collection = core_file.parent.id
    user = current_user

    if current_user.admin?
      collection_pid = params[:collection_pid]
      if Collection.exists?(collection_pid)
        core_file.set_parent(Collection.find(collection_pid), current_user)
        # Reconcile compilations
        Cerberus::Application::Queue.push(ReconcileCompilationsJob.new(params[:id]))
        flash[:notice] = "This file has been moved."
        redirect_to core_file and return
      else
        flash[:error] = "That collection does not exist. Please submit a new request and enter a valid collection PID."
        redirect_to core_file and return
      end
    else
      reason = params[:reason]
      collection_url = params[:collection_url]
      collection_pid = collection_url[/([^\/]+)$/]
      if Collection.exists?(collection_pid)
        MoveMailer.move_alert(core_file, reason, collection_url, user).deliver!
        flash[:notice] = "Your request has been received and will be processed soon."
        redirect_to core_file and return
      else
        flash[:error] = "That collection does not exist. Please submit a new request and enter a valid collection URL."
        redirect_to core_file and return
      end
    end
  end

  def get_associated_files
    @forced_view = "drs-items-list"
    @core_file = fetch_solr_document
    self.solr_search_params_logic += [:filter_by_associated_files]
    (@response, @document_list) = get_search_results
    respond_to do |format|
      format.js {
        if @response.response['numFound'] == 0
          render js: "$('#associated_files').html('No associated files were found.');"
        else
          render "associated_files"
        end
      }
    end
  end

  def get_all_associated_child_files
    @forced_view = "drs-items-list"
    @core_file = fetch_solr_document
    self.solr_search_params_logic += [:filter_by_all_associated_child_files]
    (@response, @document_list) = get_search_results
    respond_to do |format|
      format.js {
        render "associated_child_files"
      }
    end
  end

  def associate
    @core_file = CoreFile.find(params[:id])
    url = params[:core_file_url]
    association_type = params[:association_type]
    if url.include? "repository.library.northeastern.edu"
      pid = url.split("/").last
      if (pid.include? "neu:") && (CoreFile.exists?(pid))
        child_file = CoreFile.find(pid)
        begin
          child_file.associate(association_type, @core_file)
          render json: { status: "success" }, status: :ok
        rescue => exception
          render json: { :error => exception.to_s }, status: :unprocessable_entity
        end
      else
        render json: { :error=> "Core file does not exist" },  status: :unprocessable_entity
      end
    else
      render json: { :error=>"URL provided does not point to the DRS" }, status: :unprocessable_entity
    end
  end

  def disassociate
    @core_file = CoreFile.find(params[:id])
    pids_to_remove = params[:pids_to_remove].split(",")
    associations = params[:associations].split(",")
    success = false
    error = ""
    pids_to_remove.each_with_index do |pid, i|
      if CoreFile.exists?(pid)
        child_file = CoreFile.find(pid)
        association_type = associations[i]
        begin
          child_file.disassociate(association_type, @core_file)
          status = "ok"
          success = true
        rescue => exception
          error = exception.to_s
          success = false
        end
      else
        success = false
        error = "Core file does not exist"
      end
    end
    if success == true
      render json: { status: "success" }, status: :ok
    else
      render json: { :error=> error },  status: :unprocessable_entity
    end
  end

  def get_page_file
    cf = params[:id]
    @full_cf_id = RSolr.escape("info:fedora/#{cf}")
    params[:per_page] = 1
    self.solr_search_params_logic += [:limit_to_ordinal_vals]
    (@response, @document_list) = get_search_results
    @pagination = paginate_params(@response)
    @document_list.each do |doc|
      if doc.ordinal_value.to_i == params[:page].to_i
        @page = doc
      end
    end
    params.delete(:per_page)
    @core_file = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{cf}\"").first)
    @page_title = "#{@core_file.title} - Page #{params[:page]}"
    respond_to do |format|
      format.js {
        if @page
          render "/page_files/show", locals:{page:@page}
        else
          @response = nil
          render js: "window.location.href = '#{core_file_path(cf)}';"
        end
      }
      format.html {
        if @page
          render "/page_files/show", locals:{core_file:@core_file, page:@page}
        else
          @response = nil
          redirect_to @core_file
        end
      }
    end
  end

  protected

    def mods_diff(mods_a, mods_b)
      return Diffy::Diff.new(mods_a, mods_b, :include_plus_and_minus_in_html => true, :context => 1).to_s(:html).html_safe
    end

    def complete?
      core = CoreFile.find(params[:id])
      if core.properties.in_progress?
        flash[:error] = "Item will be available for edit/update when it has finished building."
        redirect_to core and return
      end
    end

    def fetch_mods
      Rails.cache.fetch("/mods/#{@core_file.pid}-#{@core_file.updated_at}", :expires_in => 12.hours) do
        Sanitize.clean(Kramdown::Document.new(render_mods_display(CoreFile.find(@core_file.pid))).to_html, :elements => ['sup', 'sub', 'dt', 'dd', 'br', 'a'], :attributes => {'a' => ['href']}).html_safe
      end
    end

    def fetch_darwin
      Rails.cache.fetch("/darwin/#{@core_file.pid}-#{@core_file.updated_at}", :expires_in => 12.hours) do
        cf = CoreFile.find(@core_file.pid)
        xml = Nokogiri::XML(cf.mods.content)

        delimiter = "|"

        begin
          output = "<dl>"

          xml.xpath("//dwc:*").each do |n|
            begin
              label = I18n.t("darwin.#{n.name}", :raise => true)
              vals = n.child.content.split(delimiter)
              output << "<dt title=\"#{label}\">#{label}:</dt>"
              vals.each do |val|
                output << "<dd>#{val}</dd>"
              end
            rescue I18n::MissingTranslationData
              # No mapping - do nothing
            end
          end

          xml.xpath("//dcterms:*").each do |n|
            begin
              label = I18n.t("dcterms.#{n.name}", :raise => true)
              vals = n.child.content.split(delimiter)
              output << "<dt title=\"#{label}\">#{label}:</dt>"
              vals.each do |val|
                output << "<dd>#{val}</dd>"
              end
            rescue I18n::MissingTranslationData
              # No mapping at all - move on
            end
          end

          output << "</dl>"

          Sanitize.clean(Kramdown::Document.new(output).to_html, :elements => ['sup', 'sub', 'dt', 'dd', 'br', 'a'], :attributes => {'a' => ['href']}).html_safe
        rescue Nokogiri::XML::XPath::SyntaxError
          # This will be thrown if the namespace isn't defined - i.e. on an older file. In which case, we move on
        end
      end
    end

    def json_error(error, name=nil, additional_arguments={})
      args = {:error => error}
      args[:name] = name if name
      render additional_arguments.merge({:json => [args]})
    end

    def no_parent_rescue(exception)
      if !session[:previous_url].blank?
        if session[:previous_url].include? "parent"
          # This particular error signature seems to indicate a timeout
          email_handled_exception(Exceptions::UploadTimeout.new())
          respond_to do |format|
            format.json { render json: { url: root_path } }
            format.html{
                redirect_to(root_path) and return
              }
          end
        end
      end

      flash[:error] = "Parent not specified or invalid"
      email_handled_exception(exception)
      respond_to do |format|
        format.json { render json: { :error=> "Error! No parent set", url: root_path } }
        format.html{
            redirect_to(root_path) and return
          }
      end
    end

    def group_permission_rescue(exception)
      flash[:error] = "Invalid form values"
      email_handled_exception(exception)
      redirect_to root_path
    end

    def update_metadata
      begin
        if !params[:core_file][:permissions].blank?
          params[:core_file][:permissions].merge!(nuid: current_user.nuid)
        end

        if @core_file.update_attributes(params[:core_file])
          flash[:notice] =  "#{@core_file.title} was updated successfully."
        end
      rescue OM::XML::TemplateMissingException => exception
        flash[:error] =  "#{@core_file.title} was not updated due to an error. DRS staff have been notified of the issue."
        email_handled_exception(exception)
      end
    end

    #Allows us to map different params
    def update_metadata_from_upload_screen(core_file, file, collection_id, tmp_path, proxy)

      if current_user.proxy_staff? && proxy == "proxy"
        core_file.depositor = Collection.find(collection_id).depositor
        core_file.proxy_uploader = current_user.nuid
      else
        core_file.depositor = current_user.nuid
      end

      core_file.tag_as_incomplete
      core_file.save!
      core_file.reload

      # Context derived attributes
      if file.original_filename.include? "."
        core_file.title = file.original_filename.split(".")[0]
      else
        core_file.title = file.original_filename
      end

      core_file.tmp_path = tmp_path
      core_file.original_filename = file.original_filename
      # core_file.label = file.original_filename

      core_file.instantiate_appropriate_content_object(tmp_path, core_file.original_filename)

      # If the content_object created is an ImageMasterFile, we want to read the image and store as session vars
      # the length of its longest side.  This is used to calculate the dimensions to allow for the small/med/large
      # sliders on the Provide Metadata page.
      if core_file.canonical_class == "ImageMasterFile"
        session[:slider_max] = nil # Ensure we aren't using data from a prior upload
        session[:slider_max] = SliderMaxCalculator.compute(tmp_path)
      end

      collection = !collection_id.blank? ? Collection.find(collection_id) : nil
      core_file.set_parent(collection, current_user) if collection

      # Featured Content tagging
      sc_type = collection.smart_collection_type

      if !sc_type.nil? && sc_type != ""
        core_file.category = sc_type
      end

      # Create a handle
      core_file.identifier = make_handle(core_file.persistent_url)

      core_file.save!
      return core_file
    end

    def process_file(file)
      if virus_check(file) == 0
        @core_file = ::CoreFile.new

        new_path = move_file_to_tmp(file)

        update_metadata_from_upload_screen(@core_file, file, params[:collection_id], new_path, params[:upload_type])
        respond_to do |format|
          format.json { render json: { url: files_provide_metadata_path(@core_file.pid) } }
        end
      else
        render :json => [{:error => "Error creating file."}]
      end
    end

    def virus_check( file)
      stat = Cerberus::ContentFile.virus_check(file)
      flash[:error] = "Virus checking did not pass for #{File.basename(file.path)} status = #{stat}" unless stat == 0
      stat
    end

    def empty_file?(file)
      (file.respond_to?(:tempfile) && file.tempfile.size == 0) || (file.respond_to?(:size) && file.size == 0)
    end

    # The name of the datastream where we store the file data
    def datastream_id
      'content'
    end

    def terms_accepted?
      params[:terms_of_service] == '1'
    end

    def title_and_keyword?
      if !(params[:core_file][:title].blank?) && !(params[:core_file][:keywords].blank?)
        if !(params[:core_file][:title].first.blank?) && !(params[:core_file][:keywords].first.blank?)
          return true
        end
      end

      # failure case
      flash[:error] = "A title and at least one keyword are required"
      return false
    end

    private

      def send_file(path, options = {})
        if options[:range]
          send_file_with_range(path, options)
        else
          super(path, options)
        end
      end

      def send_file_with_range(path, options = {})
        if File.exist?(path)
          size = File.size(path)
          if !request.headers["Range"]
            status_code = 200 # 200 OK
            offset = 0
            length = File.size(path)
          else
            status_code = 206 # 206 Partial Content
            bytes = Rack::Utils.byte_ranges(request.headers, size)[0]
            offset = bytes.begin
            length = bytes.end - bytes.begin
          end
          response.header["Accept-Ranges"] = "bytes"
          response.header["Content-Range"] = "bytes #{bytes.begin}-#{bytes.end}/#{size}" if bytes

          send_data IO.binread(path, length, offset), options
        else
          raise ActionController::MissingFile, "Cannot read file #{path}."
        end
      end

      def verify_staff_or_beta
        if !(current_user.repo_staff? || current_user.beta?)
          flash[:error] = "You do not have privileges to use that feature"
          redirect_to root_path
        end
      end

      def verify_admin
        if current_user.nil?
          flash[:error] = "You do not have privileges to use that feature"
          render_403
        elsif !(current_user.admin? || current_user.admin_group?)
          flash[:error] = "You do not have privileges to use that feature"
          render_403
        end
      end

      def filter_by_associated_files(solr_parameters, user_parameters)
        solr_parameters[:fq] ||= []
        query = []
        str = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{@core_file.pid}"
        query << "is_supplemental_material_for_ssim:\"#{str}\" || is_instructional_material_for_ssim:\"#{str}\" || is_transcription_of_ssim:\"#{str}\""
        all = []
        @core_file['is_supplemental_material_for_ssim'].to_a.each do |x|
          all << x
        end
        @core_file['is_instructional_material_for_ssim'].to_a.each do |x|
          all << x
        end
        @core_file['is_transcription_of_ssim'].to_a.each do |x|
          all << x
        end
        if all.count > 0
          all.each do |x|
            if !x.nil?
              x = x.split("/").last
              query << "id:\"#{x}\""
            end
          end
        end
        full_self_id = RSolr.escape("info:fedora/#{@core_file.pid}")
        query << "(#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:PageFile\" AND #{Solrizer.solr_name("is_part_of", :symbol)}:\"#{full_self_id}\")"
        solr_parameters[:sort] = "ordinal_value_isi asc, title_ssi asc"
        solr_parameters[:fq] << query.join(" OR ")
      end

      def filter_by_all_associated_child_files(solr_parameters, user_parameters)
        solr_parameters[:fq] ||= []
        query = []
        str = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{@core_file.pid}"
        query << "is_supplemental_material_for_ssim:\"#{str}\" || is_instructional_material_for_ssim:\"#{str}\" || is_codebook_for_ssim:\"#{str}\" || is_dataset_for_ssim:\"#{str}\" || is_figure_for_ssim:\"#{str}\" || is_transcription_of_ssim:\"#{str}\""
        solr_parameters[:sort] = "title_ssi asc"
        solr_parameters[:fq] << query
      end

      def limit_to_ordinal_vals(solr_parameters, user_parameters)
        solr_parameters[:fq] ||= []
        solr_parameters[:fq] << "active_fedora_model_ssi:PageFile AND is_part_of_ssim:#{@full_cf_id}"
        # solr_parameters[:df] = 1
        solr_parameters[:per_page] = 1
        # solr_parameters[:rows] = 1
        solr_parameters[:sort] = "ordinal_value_isi asc"
        solr_parameters[:fl] = "id, ordinal_value_isi"
      end

      def class_for_attached_file(core_file)
        klass = core_file.canonical_class.constantize
        if klass == AudioFile
          klass = AudioMasterFile
        elsif klass == VideoFile
          klass = VideoMasterFile
        end
        return klass
      end
end
