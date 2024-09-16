# frozen_string_literal: true

require 'rails_helper'

describe Blacklight::MetadataFieldLayoutComponent do
  include ViewComponent::TestHelpers

  let(:field) do
    instance_double(
      Blacklight::FieldPresenter,
      key: 'title',
      label: 'Title',
      values: ['Book Title']
    )
  end

  let(:field_for_nil_test) do
    instance_double(
      Blacklight::FieldPresenter,
      key: 'author',
      label: 'Author',
      values: [nil]
    )
  end


  describe 'rendering' do
    it 'renders the label and value with block' do
      result = render_inline(described_class.new(field: field)) do |component|
        component.with_label { field.label }
        component.with_value { field.values.first.upcase }
      end

      expect(result.css('dt.blacklight-title')).to be_present
      expect(result.css('dt').text).to eq('Title')
      expect(result.css('dd.blacklight-title')).to be_present
      expect(result.css('dd').text).to eq('BOOK TITLE')
    end

    it 'renders the label and value without block (else branch)' do
      result = render_inline(described_class.new(field: field)) do |component|
        component.with_label { field.label }
        component.with_value(value: field.values.first)
      end

      expect(result.css('dt.blacklight-title')).to be_present
      expect(result.css('dt').text).to eq('Title')
      expect(result.css('dd.blacklight-title')).to be_present
      expect(result.css('dd').text).to eq('Book Title')
    end

    it 'renders label (nil branch)' do
      result = render_inline(described_class.new(field: field_for_nil_test, value_tag: nil)) do |component|
        component.with_label { field_for_nil_test.label }
        component.with_value { field_for_nil_test.values.first }
      end

      expect(result.css('dt.blacklight-author')).to be_present
      expect(result.css('dt').text).to eq('Author')
      expect(result.css('dd')).not_to be_present
    end
  end
end

