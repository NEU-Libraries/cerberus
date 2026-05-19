# frozen_string_literal: true

class ThumbnailCreator < ApplicationService
  def initialize(base:)
    @base = base
  end

  def call
    {
      'thumbnail'    => "#{@base}/full/!85,85/0/default.jpg",
      'thumbnail_2x' => "#{@base}/full/!170,170/0/default.jpg",
      'preview'      => "#{@base}/full/500,/0/default.jpg"
    }
  end
end
