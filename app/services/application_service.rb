# frozen_string_literal: true

class ApplicationService
  def self.call(**kwargs)
    new(**kwargs).call
  end
end
