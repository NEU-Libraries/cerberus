# frozen_string_literal: true

require 'rails_helper'

# Wiring coverage for the signed-assertion relay — the sole Cerberus→Atlas auth
# path now that cerberus_token is retired (step C). config/initializers/atlas_rb.rb
# unconditionally registers atlas_rb's assertion_signing_key / assertion_signing_kid
# slots (gem >= 1.3.9) from credentials, so every relay request is signed.
#
# These specs verify Cerberus's substrate — that the initializer wired the
# callables to credentials and that atlas_rb emits an ES256 assertion matching
# Atlas's contract: no `User:` / `On-Behalf-Of:` headers; iss/aud/sub/kid as
# Atlas requires; and acting-as carried as a signed `obo` claim (not a forgeable
# header). atlas_rb's own specs cover the header-building internals; this is the
# seam where Cerberus's credentials meet the gem.
RSpec.describe 'Signed-assertion relay wiring via AtlasRb.config' do
  # A throwaway EC P-256 key so the spec is hermetic — it doesn't depend on the
  # real provisioned credentials (or the master key) being present.
  let(:signing_key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:kid)         { 'cerberus-2026-06' }

  before do
    Current.nuid = '000000002'
    allow(Rails.application.credentials).to receive(:cerberus_signing_key)
      .and_return(signing_key.to_pem)
    allow(Rails.application.credentials).to receive(:cerberus_signing_kid)
      .and_return(kid)
  end

  # Headers of a freshly-built connection for the given acting-as target.
  def connection_headers(on_behalf_of: nil)
    Current.on_behalf_of = on_behalf_of
    AtlasRb::Work.connection({}).headers
  end

  it 'wires the signing key + kid from credentials, unconditionally' do
    expect(AtlasRb.config.assertion_signing_key.call).to eq(signing_key.to_pem)
    expect(AtlasRb.config.assertion_signing_kid.call).to eq(kid)
  end

  it "signs an ES256 assertion matching Atlas's contract and sends no User: header" do
    headers = connection_headers
    expect(headers['User']).to be_nil

    token = headers['Authorization'].delete_prefix('Bearer ')
    payload, header = JWT.decode(token, signing_key, true, algorithm: 'ES256')

    expect(header).to include('alg' => 'ES256', 'kid' => kid)
    expect(payload).to include('iss' => 'cerberus', 'aud' => 'atlas', 'sub' => '000000002')
    expect(payload).not_to have_key('obo')
    expect(payload['exp']).to be > payload['iat']
  end

  it 'carries acting-as as a signed obo claim, not a forgeable header' do
    headers = connection_headers(on_behalf_of: '000000005')
    expect(headers['User']).to be_nil
    expect(headers['On-Behalf-Of']).to be_nil

    token = headers['Authorization'].delete_prefix('Bearer ')
    payload, = JWT.decode(token, signing_key, true, algorithm: 'ES256')
    expect(payload).to include('sub' => '000000002', 'obo' => '000000005')
  end
end
