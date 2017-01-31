class Assembly < ApplicationRecord
  # wrapper object of a ruby Set of ids so we can bypass fedora and slow rdf
  # for compilations, which are often compared to and edited (and don't require
  # long term preservation)
  serialize :id_list, Set
end
