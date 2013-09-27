RSpec::Matchers.define :be_thumby_label_for do |expected| 
  match do |actual| 
    if expected.instance_of?(ImageMasterFile) || expected.instance_of?(PdfFile) 
      e = expected.label.split(".") 
      e[0] = "#{e[0]}_thumb" 
      e[-1] = "png" 
      actual == e.join(".") 
    end
  end
end