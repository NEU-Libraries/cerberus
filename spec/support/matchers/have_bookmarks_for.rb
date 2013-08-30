RSpec::Matchers.define :have_bookmarks_for do |expected| 
  match do |actual|
    actual_sorted = actual.sort
    fedora_result = fedora_array(expected).sort  
    actual_sorted == fedora_result
  end
end

# Takes a string array of Fedora PIDS 
def fedora_array(array_of_pids)
  prepend_part = "info:fedora/"
  prepend_array = array_of_pids.map { |pid| prepend_part + pid } 
  return prepend_array
end
