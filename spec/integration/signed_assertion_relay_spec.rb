# frozen_string_literal: true

require 'rails_helper'

# Wiring coverage for the signed-assertion relay cutover (step B of retiring
# cerberus_token). config/initializers/atlas_rb.rb registers atlas_rb's
# `assertion_signing_key` / `assertion_signing_kid` slots (gem >= 1.3.8), both
# gated live on config.x.cerberus.sign_assertions (CERBERUS_SIGN_ASSERTIONS).
#
# These specs verify Cerberus's substrate — that the initializer wired the
# callables, that the flag gates them, and that with the flag on atlas_rb
# actually emits an ES256 assertion matching Atlas's contract (no `User:`
# header; iss/aud/sub/kid as Atlas requires). atlas_rb's own specs cover the
# header-building internals; this is the seam where Cerberus's credentials +
# flag meet the gem.
RSpec.describe 'Signed-assertion relay wiring via AtlasRb.config' do
  # A throwaway EC P-256 key so the spec is hermetic — it doesn't depend on the
  # real provisioned credentials (or the master key) being present.
  let(:signing_key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:kid)         { 'cerberus-2026-06' }

  around do |example|
    original = Rails.application.config.x.cerberus.sign_assertions
    Rails.application.config.x.cerberus.sign_assertions = sign_assertions
    example.run
    Rails.application.config.x.cerberus.sign_assertions = original
  end

  before do
    Current.nuid = '000000002'
    allow(Rails.application.credentials).to receive(:cerberus_signing_key)
      .and_return(signing_key.to_pem)
    allow(Rails.application.credentials).to receive(:cerberus_signing_kid)
      .and_return(kid)
  end

  # Authorization bearer of a freshly-built connection, and whether it carries a
  # `User:` identity header.
  def auth_header(on_behalf_of: nil)
    Current.on_behalf_of = on_behalf_of
    AtlasRb::Work.connection({}).headers
  end

  context 'with the cutover flag off (default dual-run state)' do
    let(:sign_assertions) { false }

    it 'leaves the signing-key callable resolving to nil' do
      expect(AtlasRb.config.assertion_signing_key.call).to be_nil
    end

    it 'keeps the legacy relay: a User: NUID header, no signed assertion' do
      headers = auth_header
      expect(headers['User']).to eq('NUID 000000002')
      # Legacy bearer is the ATLAS_TOKEN relay value, not a 3-segment JWT.
      expect(headers['Authorization'].delete_prefix('Bearer ')).not_to include('.')
    end
  end

  context 'with the cutover flag on' do
    let(:sign_assertions) { true }

    it 'resolves the signing key + kid from credentials' do
      expect(AtlasRb.config.assertion_signing_key.call).to eq(signing_key.to_pem)
      expect(AtlasRb.config.assertion_signing_kid.call).to eq(kid)
    end

    it 'signs an ES256 assertion matching Atlas\'s contract and drops User:' do
      headers = auth_header
      expect(headers['User']).to be_nil

      token = headers['Authorization'].delete_prefix('Bearer ')
      payload, header = JWT.decode(token, signing_key, true, algorithm: 'ES256')

      expect(header).to include('alg' => 'ES256', 'kid' => kid)
      expect(payload).to include(
        'iss' => 'cerberus',
        'aud' => 'atlas',
        'sub' => '000000002'
      )
      expect(payload['exp']).to be > payload['iat']
    end

    it 'falls back to the legacy relay for acting-as (On-Behalf-Of) requests' do
      headers = auth_header(on_behalf_of: '000000005')
      expect(headers['User']).to eq('NUID 000000002')
      expect(headers['On-Behalf-Of']).to eq('NUID 000000005')
      expect(headers['Authorization'].delete_prefix('Bearer ')).not_to include('.')
    end
  end
end
