# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Blacklight::Gallery::DocumentTitleComponent, type: :component do
  # Blacklight's initializer reads presenter.document to build the deprecated
  # @document proxy, so the double has to answer it.
  let(:presenter) { instance_double('Blacklight::IndexPresenter', document: SolrDocument.new(id: 'abc123')) }

  it 'defaults heading level to :h5 (overrides Blacklight default of :h3)' do
    component = described_class.new(presenter: presenter)

    expect(component.instance_variable_get(:@as)).to eq(:h5)
  end

  it 'applies the gallery title CSS classes by default' do
    component = described_class.new(presenter: presenter)

    expect(component.instance_variable_get(:@classes)).to include('gallery-title')
  end

  # Blacklight sizes document titles through this class rather than a
  # stylesheet rule, so a replacement class list has to carry it or the
  # gallery title drops to body weight and leading.
  it 'keeps the h5 sizing class that Blacklight carries in the class list' do
    component = described_class.new(presenter: presenter)

    expect(component.instance_variable_get(:@classes)).to include('h5')
  end

  it 'forwards explicit overrides via **kwargs (e.g., link_to_document)' do
    component = described_class.new(presenter: presenter, link_to_document: false)

    expect(component.instance_variable_get(:@link_to_document)).to eq(false)
  end
end
