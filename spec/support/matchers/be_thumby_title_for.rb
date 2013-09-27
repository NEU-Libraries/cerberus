RSpec::Matchers.define :be_thumby_title_for do |expected| 
  match do |actual| 
    e = expected.split(".") 
    e[0] = "#{e[0]}_thumb" 

    actual == e.join(".") 
  end
end