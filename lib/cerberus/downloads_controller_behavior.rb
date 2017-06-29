module Cerberus
  module DownloadsControllerBehavior
    extend ActiveSupport::Concern
    include Hydra::Controller::DownloadBehavior
    include MimeHelper

    included do
      # module mixes in normalize_identifier method
      include Cerberus::Noid

      # moved check into the routine so we can handle the user with no access
      prepend_before_filter :normalize_identifier
    end

    # overriding hydra-head 6.3.3
    def send_content(asset)
      # Fuzzy thumbnails with send_file for some reason...small kludge. Everything else, don't use Hydra
      # Collections and others can have non-standard thumbnails - inlcuding a check to see if it's a "true" content type
      if asset.class == ZipFile
        file_name = "neu_#{asset.pid.split(":").last}.zip"
        send_file asset.fedora_file_path, :filename =>  file_name, :type => "application/zip", :disposition => 'inline'
      elsif !(asset.class == ImageThumbnailFile || asset.class == PageFile) && (asset.datastreams.keys.include? "content")
        file_name = "neu_#{asset.pid.split(":").last}.#{extract_extension(asset.properties.mime_type.first, File.extname(asset.original_filename || "").delete!("."))}"
        send_file asset.fedora_file_path, :filename =>  file_name, :type => asset.mime_type || extract_mime_type(asset.fedora_file_path), :disposition => 'inline'
      else
        super
      end
    end

    # overriding hydra-head 6.3.3
    # render an HTTP HEAD response
    def content_head
      response.headers['Content-Length'] = datastream.dsSize
      # mimeType gets from Fedora, which fails when you've incorrectly
      # given the mime type - Migration from IRis had some tiffs as jpegs
      # mimeType gets from the 1st version (instead of the lastest), so
      # rather than re-do thousands of items, we're going to rely on FITS instead
      # response.headers['Content-Type'] = datastream.mimeType
      response.headers['Content-Type'] = asset.properties.mime_type.first
      head :ok
    end

    def datastream_name
      if datastream.dsid == self.class.default_content_dsid
        # params[:filename] || asset.label
        # Fix for #680
        "neu_#{asset.pid.split(":").last}.#{extract_extension(asset.properties.mime_type.first, File.extname(asset.original_filename || "").delete!("."))}"
      else
        params[:datastream_id]
      end
    end

  end
end