include MimeHelper
require 'open-uri'

class WowzaController < ApplicationController
  def plain
    # "http://libwowza.neu.edu/datastreamStore/cerberusData/newfedoradata/datastreamStore/#{dir}/" + encodeURIComponent("info%3Afedora%2F#{encoded}%2Fcontent%2Fcontent.0"), type:"#{type.downcase}"
    doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first

    dir = doc.pid_hash[0,2]
    encoded = doc.encode

    url_str = "http://libwowza.neu.edu/datastreamStore/cerberusData/newfedoradata/datastreamStore/#{dir}/" + CGI::escape("info%3Afedora%2F#{encoded}%2Fcontent%2Fcontent.0")
    stream(url_str, doc, doc.mime_type)
  end

  # def rtmp
    # After testing, this never worked in the old style, as the url was wrong
    # Not implementing, due to the above (and no one noticed) and because proxying RTMP is too difficult

    # "rtmp://libwowza.neu.edu:1935/vod/_definst_/#{type}:datastreamStore/cerberusData/newfedoradata/datastreamStore/#{dir}/info%3Afedora%2F#{encoded}%2Fcontent%2Fcontent.0"

    # should have been

    # "rtmp://libwowza.neu.edu:1935/vod/_definst_/datastreamStore/cerberusData/newfedoradata/datastreamStore/#{dir}/#{doc_type(doc)}:" + CGI::escape("info%3Afedora%2F#{encoded}%2Fcontent%2Fcontent.0")
  # end

  def playlist
    # "http://libwowza.neu.edu:1935/vod/_definst_/datastreamStore/cerberusData/newfedoradata/datastreamStore/#{dir}/#{type}:" + encodeURIComponent("info%3Afedora%2F#{encoded}%2Fcontent%2Fcontent.0") + "/playlist.m3u8"
    doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first

    dir = doc.pid_hash[0,2]
    encoded = doc.encode

    url_str = "http://libwowza.neu.edu:1935/vod/_definst_/datastreamStore/cerberusData/newfedoradata/datastreamStore/#{dir}/#{doc_type(doc)}:" + CGI::escape("info%3Afedora%2F#{encoded}%2Fcontent%2Fcontent.0") + "/playlist.m3u8"

    data = open(url_str)
    chunk_str = data.each_line.select{ |l| l.start_with?("chunk")}.first.squish

    url_str = "http://libwowza.neu.edu:1935/vod/_definst_/datastreamStore/cerberusData/newfedoradata/datastreamStore/#{dir}/#{doc_type(doc)}:" + CGI::escape("info%3Afedora%2F#{encoded}%2Fcontent%2Fcontent.0") + "/#{chunk_str}"

    stream(url_str, doc, "application/x-mpegURL")
  end

  def stream
    # https://repository.library.northeastern.edu/wowza/neu:m039rj57d/media_w240930_0.ts
    # "http://libwowza.neu.edu:1935/vod/_definst_/datastreamStore/cerberusData/newfedoradata/datastreamStore/5e/MP4:info%253Afedora%252Fneu%253Am039qq36h%252Fcontent%252Fcontent.0/media_w1480328487_97.ts"
    # params[:part]
    # video/MP2T
    doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first

    dir = doc.pid_hash[0,2]
    encoded = doc.encode

    url_str = "http://libwowza.neu.edu:1935/vod/_definst_/datastreamStore/cerberusData/newfedoradata/datastreamStore/#{dir}/#{doc_type(doc)}:" + CGI::escape("info%3Afedora%2F#{encoded}%2Fcontent%2Fcontent.0") + "/#{params[:part]}"

    data = open(url_str)

    send_data(data.read, filename: params[:part])
  end

  private

    def stream(url_str, doc, mime_type_str)
      if (!current_user.nil? && (current_user.can? :read, doc)) || doc.public?
        if doc.mime_type == 'video/mp4' || doc.mime_type == 'video/quicktime' || doc.mime_type == 'audio/mpeg'
          data = open(url_str)

          if mime_type_str == "application/x-mpegURL"
            send_data(data.read, type: mime_type_str, filename: 'playlist.m3u8')
          else
            send_data(data.read, type: mime_type_str, filename: "media." + "#{extract_extension(doc.mime_type)}")
          end

        else
          # Raise error
          render_500(StandardError.new) and return
        end
      else
        # Raise 403
        render_403 and return
      end
    end

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
