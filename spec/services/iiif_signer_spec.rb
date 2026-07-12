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
      expect(exp.to_i).to be_within(5).of(1.hour.from_now.to_i)
    end

    it 'preserves host and path prefix so a proxied /cantaloupe base still resolves' do
      signed = IiifSigner.sign_identifier('https://h.example/cantaloupe/iiif/3/gated-abc.jp2')

      expect(signed).to start_with('https://h.example/cantaloupe/iiif/3/')
      expect(signed).to end_with('~gated-abc.jp2')
    end

    it 'honors a custom ttl' do
      expect(parts(IiifSigner.sign_identifier(base, ttl: 10.minutes)).first.to_i)
        .to be_within(5).of(10.minutes.from_now.to_i)
    end
  end

  describe '.grant_cookie' do
    it 'is a time-boxed "exp|hmac" pass a verifier can recompute' do
      exp, sig = IiifSigner.grant_cookie.split('|')

      expect(sig).to eq(OpenSSL::HMAC.hexdigest('SHA256', secret, "grant|#{exp}"))
      expect(exp.to_i).to be_within(5).of(1.hour.from_now.to_i)
    end
  end

  describe 'without a configured secret' do
    it 'raises rather than minting an unsigned credential' do
      allow(Rails.application.config.x.cerberus).to receive(:iiif_signing_secret).and_return(nil)

      expect { IiifSigner.sign_url(url) }.to raise_error(ArgumentError, /SIGNING_SECRET/)
    end
  end
end
