# frozen_string_literal: true

require 'rails_helper'

describe ApplicationHelper do
  describe 'application_version' do
    it 'returns the VERSION constant' do
      stub_const('VERSION', '1.0.0')
      expect(helper.application_version).to eq('1.0.0')
    end
  end

  describe 'iiif_url' do
    let(:uuid) { 'test' }

    it 'has a present iiif host' do
      allow(Rails.application.config).to receive(:iiif_host).and_return('http://example.com')
      expected_url = 'http://example.com/iiif/3/test.jp2'
      expect(helper.iiif_url(uuid)).to eq(expected_url)
    end

    it 'lacks a present iiif host' do
      allow(Rails.application.config).to receive(:iiif_host).and_return(nil)
      allow(helper).to receive_message_chain(:request, :host).and_return('host')
      expected_url = 'http://host:8182/iiif/3/test.jp2'
      expect(helper.iiif_url(uuid)).to eq(expected_url)
    end
  end
end
