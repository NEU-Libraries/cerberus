# frozen_string_literal: true

class DerivativeCreator < ApplicationService
  def initialize(base:)
    @base = base
  end

  def call
    {
      'small'  => "#{@base}/full/800,/0/default.jpg",
      'medium' => "#{@base}/full/1600,/0/default.jpg",
      'large'  => "#{@base}/full/full/0/default.jpg"
    }
  end
end
