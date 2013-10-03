RSpec::Matchers.define :be_thumby_label_for do |expected| 
  match do |actual| 
    e = expected.label.split(".") 
    e[0] = "#{e[0]}_thumb" 
    e[-1] = "png" 
    actual == e.join(".")
  end

  failure_message_for_should do |actual| 
    "expected #{actual} to be thumbnailized label for #{expected.label}"
  end
end