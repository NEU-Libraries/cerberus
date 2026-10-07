# frozen_string_literal: true

require 'spec_helper'
require 'openssl'

# The Cantaloupe delegate is plain Ruby that Cantaloupe loads through JRuby, so
# it can be exercised here without the image server. It reads its secret into a
# constant at load time, so the secret is set around the load and restored.
previous = ENV.fetch('CERBERUS_IIIF_SIGNING_SECRET', nil)
ENV['CERBERUS_IIIF_SIGNING_SECRET'] = 'delegate-spec-secret'
load File.expand_path('../../docker/cantaloupe/delegates.rb', __dir__)
ENV['CERBERUS_IIIF_SIGNING_SECRET'] = previous

RSpec.describe CustomDelegate do
  subject(:delegate) { described_class.new.tap { |d| d.context = context } }

  let(:context) { { 'identifier' => identifier } }
  let(:open_name) { 'open-5b1ce000-0000-4000-8000-000000000001.tif' }
  let(:gated_name) { 'gated-5b1ce000-0000-4000-8000-000000000001.tif' }

  def token(real, exp: Time.now.to_i + 600)
    "#{exp}~#{OpenSSL::HMAC.hexdigest('SHA256', CustomDelegate::SECRET, "#{real}|#{exp}")}~#{real}"
  end

  describe 'resolving a file' do
    let(:identifier) { open_name }

    it 'maps an open name into the image root' do
      expect(delegate.filesystemsource_pathname).to eq("/imageroot/#{open_name}")
    end

    it 'strips a deep-zoom token back to the gated file' do
      context['identifier'] = token(gated_name)
      expect(delegate.filesystemsource_pathname).to eq("/imageroot/#{gated_name}")
    end
  end

  describe 'names it will not resolve' do
    ['open-5b1ce000.jp2', 'open-5b1ce000.png', 'open-5b1ce000.tiff', '../etc/passwd.tif', 'other-5b1ce000.tif'].each do |name|
      context "with #{name}" do
        let(:identifier) { name }

        it { expect(delegate.filesystemsource_pathname).to be_nil }
      end
    end
  end

  describe 'authorizing' do
    let(:identifier) { gated_name }

    it 'admits an open image without a credential' do
      context['identifier'] = open_name
      expect(delegate.pre_authorize).to be(true)
    end

    it 'refuses a gated image with no credential' do
      expect(delegate.pre_authorize).to eq('status_code' => 403)
    end

    it 'admits a gated image with a valid token' do
      context['identifier'] = token(gated_name)
      expect(delegate.pre_authorize).to be(true)
    end

    it 'refuses an expired token' do
      context['identifier'] = token(gated_name, exp: Time.now.to_i - 1)
      expect(delegate.pre_authorize).to eq('status_code' => 403)
    end

    it 'refuses a token minted for a different image' do
      other = 'gated-5b1ce000-0000-4000-8000-000000000002.tif'
      context['identifier'] = token(gated_name).sub(gated_name, other)
      expect(delegate.pre_authorize).to eq('status_code' => 403)
    end
  end
end
