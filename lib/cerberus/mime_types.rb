module Cerberus
  module MimeTypes
    extend ActiveSupport::Concern

    def is_image?
    end

    def is_pdf?
    end

    def is_video?
    end

    def is_audio?
    end

    def is_msword?
    end

    def is_msexcel?
    end

    def is_msppt?
    end

    def is_texty?
    end

  end
end
