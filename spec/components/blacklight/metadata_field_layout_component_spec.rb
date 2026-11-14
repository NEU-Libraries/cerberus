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

  # The toggle's name is its own "Show full" plus the field label, so each
  # value's button says which field it opens; aria-controls and aria-expanded
  # tie it to the value it clamps.
  it 'gives each value a clamp toggle named after the field and tied to its value' do
    render_inline(described_class.new(field: field)) do |c|
      c.with_label { 'Abstract' }
      c.with_value { 'first value' }
      c.with_value { 'second value' }
    end

    label_id = page.find('dt', text: 'Abstract')[:id]
    toggles = page.all('dd button.metadata-section-toggle', visible: :all)
    expect(toggles.size).to eq(2)
    toggles.each do |toggle|
      expect(toggle[:'aria-expanded']).to eq('false')
      expect(toggle[:'aria-label']).to eq('Show full')
      expect(toggle[:'aria-labelledby'].split).to eq([toggle[:id], label_id])
      expect(page).to have_css("##{toggle[:'aria-controls']}.metadata-section-clamped", visible: :all)
    end
    expect(toggles.pluck(:'aria-controls').uniq.size).to eq(2)
  end

  it 'keeps ids unique when the same field renders twice' do
    ids = Array.new(2) do
      render_inline(described_class.new(field: field)) do |c|
        c.with_label { 'Abstract' }
        c.with_value { 'value' }
      end
      page.find('dt')[:id]
    end

    expect(ids.uniq.size).to eq(2)
  end
end
