require 'open-uri'

class WowzaController < ApplicationController
  include Cerberus::ControllerHelpers::ViewLogger
  include MimeHelper
  def plain
    doc = fetch_solr_document

    if (!current_user.nil? && (current_user.can? :read, doc)) || doc.public?
      asset = ActiveFedora::Base.find(doc.pid, cast: true)
      if request.headers["Range"].blank?
        log_action('download', 'COMPLETE', asset.pid)
      else
        log_action("stream", "COMPLETE", asset.pid)
      end

      file_name = "neu_#{asset.pid.split(":").last}.#{extract_extension(asset.properties.mime_type.first, File.extname(asset.original_filename || "").delete!("."))}"
      send_file asset.fedora_file_path, :range => true, :filename => file_name, :type => asset.mime_type || extract_mime_type(asset.fedora_file_path), :disposition => 'inline'
    else
      # Raise 403
      render_403 and return
    end
  end

  def playlist
    doc = fetch_solr_document

    if (!current_user.nil? && (current_user.can? :read, doc)) || doc.public?
      if doc.mime_type == 'video/mp4' || doc.mime_type == 'video/quicktime' || doc.mime_type == 'audio/mpeg'
        dir = doc.pid_hash[0,2]
        encoded = doc.encode

        url_str = "http://libwowza.neu.edu:1935/vod/_definst_/datastreamStore/cerberusData/newfedoradata/datastreamStore/#{dir}/#{doc_type(doc)}:" + CGI::escape("info%3Afedora%2F#{encoded}%2Fcontent%2Fcontent.0") + "/playlist.m3u8"

        data = open(url_str)
        chunk_str = data.each_line.select{ |l| l.start_with?("chunk")}.first.squish

        url_str = "http://libwowza.neu.edu:1935/vod/_definst_/datastreamStore/cerberusData/newfedoradata/datastreamStore/#{dir}/#{doc_type(doc)}:" + CGI::escape("info%3Afedora%2F#{encoded}%2Fcontent%2Fcontent.0") + "/#{chunk_str}"

        data = open(url_str)

        log_action("stream", "COMPLETE", params[:id])
        send_data(data.read, type: "application/x-mpegURL", filename: 'playlist.m3u8')
      else
        # Raise error
        render_500(StandardError.new) and return
      end
    else
      # Raise 403
      render_403 and return
    end
  end

  def part
    doc = fetch_solr_document

    dir = doc.pid_hash[0,2]
    encoded = doc.encode

    url_str = "http://libwowza.neu.edu:1935/vod/_definst_/datastreamStore/cerberusData/newfedoradata/datastreamStore/#{dir}/#{doc_type(doc)}:" + CGI::escape("info%3Afedora%2F#{encoded}%2Fcontent%2Fcontent.0") + "/#{params[:part]}"

    data = open(url_str)

    send_data(data.read, filename: params[:part])
  end

  private

    def doc_type(doc)
      type_val = ''

      if doc.mime_type == 'video/mp4' || doc.mime_type == 'video/quicktime'
        type_val = 'MP4'
      elsif doc.mime_type == 'audio/mpeg'
        type_val = 'MP3'
      end

      return type_val
    end

end
