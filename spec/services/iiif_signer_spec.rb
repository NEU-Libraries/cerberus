# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IiifSigner do
  let(:secret) { 'test-secret' }
  let(:url) { 'https://gated.example/iiif/3/abc.jp2/full/pct:75/0/default.jpg' }

  before { allow(Rails.application.config.x.cerberus).to receive(:iiif_signing_secret).and_return(secret) }

  def query(signed) = URI.decode_www_form(URI.parse(signed).query).to_h

  describe '.sign_url' do
    it 'appends exp and an HMAC over the request path + exp that a verifier can recompute' do
      params = query(IiifSigner.sign_url(url))
      expected = OpenSSL::HMAC.hexdigest('SHA256', secret, "/iiif/3/abc.jp2/full/pct:75/0/default.jpg|#{params['exp']}")

      expect(params['sig']).to eq(expected)
      expect(params['exp'].to_i).to be_within(5).of(5.minutes.from_now.to_i)
    end

    it 'binds the size: a signature for one size does not validate another' do
      med = query(IiifSigner.sign_url('https://g/iiif/3/x.jp2/full/pct:50/0/default.jpg'))
      max = query(IiifSigner.sign_url('https://g/iiif/3/x.jp2/full/max/0/default.jpg'))

      expect(med['sig']).not_to eq(max['sig'])
    end

    it 'honors a custom ttl' do
      expect(query(IiifSigner.sign_url(url, ttl: 2.hours))['exp'].to_i).to be_within(5).of(2.hours.from_now.to_i)
    end
  end

  describe '.sign_identifier' do
    let(:base) { 'https://gated.example/iiif/3/gated-abc.jp2' }

    def parts(signed) = URI.parse(signed).path.split('/').last.split('~', 3)

    it 'rewrites the identifier to <exp>~<sig>~<identifier>, HMAC over "<identifier>|<exp>"' do
      exp, sig, real = parts(IiifSigner.sign_identifier(base))

      expect(real).to eq('gated-abc.jp2')
      expect(sig).to eq(OpenSSL::HMAC.hexdigest('SHA256', secret, "gated-abc.jp2|#{exp}"))
    end

    it 'quantizes exp to a ttl-sized epoch-aligned window valid for [ttl, 2*ttl)' do
      window = 1.hour.to_i
      exp = parts(IiifSigner.sign_identifier(base)).first.to_i

      # Aligned to the window so repeated views land on the same value, and
      # always at least `ttl` in the future so a token never expires mid-view.
      expect(exp % window).to eq(0)
      expect(exp - Time.now.to_i).to be_between(window - 5, 2 * window)
    end

    it 'mints a byte-identical identifier for repeated views in the same window' do
      # The stable cache key that lets Cantaloupe serve cached tiles across
      # reloads instead of re-decoding the source each time.
      expect(IiifSigner.sign_identifier(base)).to eq(IiifSigner.sign_identifier(base))
    end

    it 'preserves host and path prefix so a proxied /cantaloupe base still resolves' do
      signed = IiifSigner.sign_identifier('https://h.example/cantaloupe/iiif/3/gated-abc.jp2')

      expect(signed).to start_with('https://h.example/cantaloupe/iiif/3/')
      expect(signed).to end_with('~gated-abc.jp2')
    end

    it 'honors a custom ttl as the quantization window' do
      window = 10.minutes.to_i
      exp = parts(IiifSigner.sign_identifier(base, ttl: 10.minutes)).first.to_i

      expect(exp % window).to eq(0)
      expect(exp - Time.now.to_i).to be_between(window - 5, 2 * window)
    end
  end

  describe 'without a configured secret' do
    it 'raises rather than minting an unsigned credential' do
      allow(Rails.application.config.x.cerberus).to receive(:iiif_signing_secret).and_return(nil)

      expect { IiifSigner.sign_url(url) }.to raise_error(ArgumentError, /SIGNING_SECRET/)
    end
  end
end
