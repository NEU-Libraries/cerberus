class NuEmployee < ActiveFedora::Base
  
  belongs_to :parent, :property => :is_member_of, :class_name => 'NuCollection'

end