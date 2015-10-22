class FileSizeGraph < ActiveRecord::Base
  attr_accessible :json_values

  def json_values=(value)
    write_attribute(:json_values, Base64.encode64(Zlib::Deflate.deflate(value)))
  end

  def json_values
    Zlib::Inflate.inflate(Base64.decode64(super))
  end
end
