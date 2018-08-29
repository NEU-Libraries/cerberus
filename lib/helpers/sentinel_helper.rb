module SentinelHelper

  def sentinel_class_to_symbol(class_string)

    model_hsh = {"AudioMasterFile"=>"audio_master", "AudioFile"=>"audio", "ImageMasterFile"=>"image_master",
                  "ImageLargeFile"=>"image_large", "ImageMediumFile"=>"image_medium",
                  "ImageSmallFile"=>"image_small", "MspowerpointFile"=>"mspowerpoint",
                  "MsexcelFile"=>"msexcel", "MswordFile"=>"msword",
                  "PageFile"=>"page", "PdfFile"=>"pdf", "TextFile"=>"text", "VideoMasterFile"=>"video_master",
                  "VideoFile"=>"video", "ZipFile"=>"zip", "EpubFile"=>"epub"}

    if !model_hsh[class_string].blank?
      return model_hsh[class_string].to_sym
    else
      return :""
    end

  end

end
