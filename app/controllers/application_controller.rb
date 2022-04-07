# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  include Croutons::Controller

  before_action do
    I18n.locale = :en
  end

  # Best to ask for breadcrumbs everywhere
  # and just avoid Croutons NotImplementedError
  def breadcrumbs
    super
  rescue NoMethodError, NotImplementedError
    # Just don't show them
    logger.info('No breadcrumbs found') && (return)
  end
end
