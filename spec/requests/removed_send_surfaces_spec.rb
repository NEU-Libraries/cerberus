# frozen_string_literal: true

require 'rails_helper'

# G5 — the unused Blacklight email/SMS send routes and the unused bookmarks
# resource are no longer mounted (they were anonymous, reachable POST
# send/abuse surfaces with no UI driving them — navbar/document_actions are
# empty). This is the living assertion that they stay gone.
RSpec.describe 'Removed open send surfaces (G5)', type: :request do
  def recognizes?(path, method: :get)
    Rails.application.routes.recognize_path(path, method: method)
    true
  rescue ActionController::RoutingError
    false
  end

  it 'no longer routes the catalog email/sms send paths' do
    expect(recognizes?('/catalog/abc123/email', method: :post)).to be(false)
    expect(recognizes?('/catalog/abc123/sms',   method: :post)).to be(false)
  end

  it 'no longer routes the bookmarks surface' do
    expect(recognizes?('/bookmarks')).to be(false)
    expect(recognizes?('/bookmarks/abc123/email', method: :post)).to be(false)
  end

  it 'drops the route helpers for the removed paths' do
    helpers = Rails.application.routes.url_helpers
    expect(helpers).not_to respond_to(:email_solr_document_path)
    expect(helpers).not_to respond_to(:sms_solr_document_path)
    expect(helpers).not_to respond_to(:bookmarks_path)
  end

  it 'still routes the catalog document show page (only the export concern was dropped)' do
    expect(recognizes?('/catalog/abc123')).to be(true)
  end
end
