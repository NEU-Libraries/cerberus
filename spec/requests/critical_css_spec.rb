# frozen_string_literal: true

require 'rails_helper'

# The three <head>s a layout page can carry. See docs/critical-css.md.
RSpec.describe 'Layout stylesheets', :critical_css, type: :request do
  let(:head) { response.body[%r{<head>.*</head>}m] }
  let(:application_css) { %r{/assets/application-\h+\.css} }

  before do
    allow(Rails.application.config.x.cerberus).to receive(:terms_document_url).and_return(nil)
  end

  describe 'a full page load' do
    before { get terms_path }

    it 'inlines the rules the page can use, and holds the first paint for the whole document' do
      expect(head).to match(/<link rel="expect" href="#blacklight-modal" blocking="render">\s*<style>:root/)
      inline = head[%r{<style>.*?</style>}m]
      expect(inline).to include('.navbar{')
      expect(inline).not_to include('.offcanvas{')
    end

    it 'loads both layout stylesheets without blocking, and applies them from a script' do
      deferred = head.scan(/<link rel="stylesheet"[^>]*media="print" data-deferred-stylesheet="true"/)

      expect(deferred.size).to eq 2
      expect(head).to include("document.querySelectorAll('link[data-deferred-stylesheet]')")
    end

    it 'keeps blocking links for a browser without JavaScript' do
      expect(head).to match(%r{<noscript><link rel="stylesheet" href="#{application_css}" media="all" />})
    end

    it 'carries the Turbo reload signature on a meta tag, never on a stylesheet' do
      expect(head).to match(/<meta name="layout-stylesheets" content="#{application_css} \S+" data-turbo-track="reload">/)
      expect(head.scan(/<link rel="stylesheet"[^>]*data-turbo-track/)).to be_empty
    end

    it 'varies on the Turbo request header' do
      expect(response.headers['Vary']).to include('X-Turbo-Request-Id')
    end
  end

  describe 'a Turbo visit' do
    before { get terms_path, headers: { 'X-Turbo-Request-Id' => SecureRandom.uuid } }

    it 'sends the signature and no layout stylesheets, which Turbo would append out of order' do
      expect(head).to include('<meta name="layout-stylesheets"')
      expect(head).not_to match(/<link rel="stylesheet"|<style>|rel="expect"/)
    end
  end

  describe 'a page rendered by a Live controller' do
    before { get download_queue_path }

    it 'keeps the blocking links, because its body is already streaming' do
      expect(response).to have_http_status(:ok)
      expect(head).to match(%r{<link rel="stylesheet" href="#{application_css}" media="all" />})
    end
  end

  describe 'when the stylesheets cannot be read' do
    before do
      allow(CriticalCss).to receive(:for).and_return(nil)
      get terms_path
    end

    it 'keeps the blocking links' do
      expect(head).to match(%r{<link rel="stylesheet" href="#{application_css}" media="all" />})
      expect(head).not_to include('data-deferred-stylesheet')
    end
  end

  describe 'when selecting the rules raises' do
    before do
      allow(CriticalCss).to receive(:for).and_raise(ArgumentError, 'bad css')
      get terms_path
    end

    it 'still renders the page, with the blocking links' do
      expect(response).to have_http_status(:ok)
      expect(head).to match(%r{<link rel="stylesheet" href="#{application_css}" media="all" />})
    end
  end
end

# Untagged, so it runs as every other request spec does: spec/support/critical_css.rb
# keeps the inline CSS out of the bodies they match against.
RSpec.describe 'Layout stylesheets outside the critical_css tag', type: :request do
  it 'renders the blocking links, with no inline CSS' do
    allow(Rails.application.config.x.cerberus).to receive(:terms_document_url).and_return(nil)
    get terms_path

    expect(response.body).to include('<!-- layout-stylesheets -->')
    expect(response.body).not_to include('data-deferred-stylesheet')
  end
end
