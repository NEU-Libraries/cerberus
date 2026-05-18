# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Blacklight::Gallery::DocumentTitleComponent, type: :component do
  let(:presenter) { instance_double('Blacklight::IndexPresenter') }

  it 'defaults heading level to :h5 (overrides Blacklight default of :h3)' do
    component = described_class.new(presenter: presenter)

    expect(component.instance_variable_get(:@as)).to eq(:h5)
  end

  it 'applies the gallery title CSS classes by default' do
    component = described_class.new(presenter: presenter)

    expect(component.instance_variable_get(:@classes)).to include('gallery-title')
  end

  it 'forwards explicit overrides via **kwargs (e.g., link_to_document)' do
    component = described_class.new(presenter: presenter, link_to_document: false)

    expect(component.instance_variable_get(:@link_to_document)).to eq(false)
  end
end
