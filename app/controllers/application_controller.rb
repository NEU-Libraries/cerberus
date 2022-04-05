# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller

  before_action do
    I18n.locale = :en
  end
end
