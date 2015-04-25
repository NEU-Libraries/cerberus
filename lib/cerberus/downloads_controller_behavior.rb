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

    def datastream_name
      if datastream.dsid == self.class.default_content_dsid
        # params[:filename] || asset.label
        # Fix for #680
        "neu_#{asset.pid.split(":").last}#{extract_extension(asset.characterization.mime_type.first)}"
      else
        params[:datastream_id]
      end
    end

  end
end
