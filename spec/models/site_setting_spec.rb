# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteSetting do
  after { described_class.delete_all }

  it 'returns nil for a key with no row' do
    expect(described_class.get('terms_document_url')).to be_nil
  end

  it 'stores a value and replaces it in the same row' do
    described_class.set('terms_document_url', '/works/abc1234')
    described_class.set('terms_document_url', '/works/def5678')

    expect(described_class.get('terms_document_url')).to eq('/works/def5678')
    expect(described_class.where(key: 'terms_document_url').count).to eq(1)
  end

  it 'reads a blank value as unset' do
    described_class.set('terms_document_url', '')
    expect(described_class.get('terms_document_url')).to be_nil
  end

  it 'refuses a key nothing reads' do
    expect { described_class.set('terms_documnet_url', '/works/abc1234') }
      .to raise_error(ActiveRecord::RecordInvalid)
  end
end
