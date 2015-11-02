class PageFile < ImageThumbnailFile
  include Cerberus::ContentFile

  def ordinal_value=(ord_val)
    self.properties.ordinal_value = ord_val
  end

  def ordinal_value
    self.properties.ordinal_value.first
  end

  def ordinal_last=(ord_last)
    self.properties.ordinal_last = ord_last
  end

  def ordinal_last
    return self.properties.ordinal_last.first == 'true'
  end
end
