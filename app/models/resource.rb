# frozen_string_literal: true

class Resource < Valkyrie::Resource
  include Cerberus::Noid
  enable_optimistic_locking
end
