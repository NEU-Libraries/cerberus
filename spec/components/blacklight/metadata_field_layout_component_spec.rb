# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Blacklight::MetadataFieldLayoutComponent, type: :component do
  let(:field) { instance_double('Blacklight::FieldPresenter', key: 'My Field') }

  it 'renders a value via a block when value_tag is nil' do
    render_inline(described_class.new(field: field)) do |c|
      c.with_label { 'My Field' }
      c.with_value { 'block-rendered' }
    end

    expect(page).to have_text('block-rendered')
  end

  it 'wraps a block in @value_tag when value_tag is set' do
    render_inline(described_class.new(field: field, value_tag: :span)) do |c|
      c.with_label { 'My Field' }
      c.with_value { 'wrapped-by-block' }
    end

    expect(page).to have_css('span', text: 'wrapped-by-block')
  end

  it 'wraps a positional value in @value_tag when value_tag is set' do
    render_inline(described_class.new(field: field, value_tag: :span)) do |c|
      c.with_label { 'My Field' }
      c.with_value(value: 'wrapped-by-value')
    end

    expect(page).to have_css('span', text: 'wrapped-by-value')
  end
end
