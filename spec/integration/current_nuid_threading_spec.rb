# frozen_string_literal: true

require 'rails_helper'

# Wiring coverage for the Option-1 ambient-NUID pattern shipped in
# Cerberus piece 6: config/initializers/atlas_rb.rb registers a
# `default_nuid` provider that reads from `Current.nuid`, and atlas_rb's
# resource methods fall through to it when `nuid:` is omitted at the
# call site.
#
# Unit specs (job + controller) verify the call shape *without* an
# explicit `nuid:` kwarg. The specs here verify Cerberus's substrate —
# that the initializer registered the right callable, and that the
# callable tracks Current.nuid live. atlas_rb's own specs cover the
# nil-positional fall-through inside FaradayHelper#connection.
RSpec.describe 'Current.nuid threading via AtlasRb.config' do
  it "registers Current.nuid as atlas_rb's default_nuid provider" do
    Current.nuid = '999000123'
    expect(AtlasRb.config.default_nuid.call).to eq('999000123')
  end

  it 'tracks Current.nuid mutations through the same callable' do
    Current.nuid = '111111111'
    expect(AtlasRb.config.default_nuid.call).to eq('111111111')
    Current.nuid = '222222222'
    expect(AtlasRb.config.default_nuid.call).to eq('222222222')
  end
end
