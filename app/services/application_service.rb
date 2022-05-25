# frozen_string_literal: true

class ApplicationService
  include MODSBuilder

  def self.call(**kwargs)
    new(**kwargs).call
  end
end
