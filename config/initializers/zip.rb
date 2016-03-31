require "zip"
Zip.setup do |z|
  z.write_zip64_support = true
end
