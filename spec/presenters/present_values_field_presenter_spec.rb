# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PresentValuesFieldPresenter do
  let(:view_context) do
    controller = CatalogController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.view_context
  end

  let(:config) { CatalogController.blacklight_config }

  def rendered_fields(presenter_class, view_config, **fields)
    document = SolrDocument.new(id: 'abc123', title_tsim: ['beach'], **fields)
    presenter_class.new(document, view_context, config, view_config: view_config)
                   .field_presenters.map(&:key)
  end

  # A container browse draws its member rows from the show config, so both
  # lists must hide a blank field.
  [[EnhancedIndexPresenter, :index], [EnhancedShowPresenter, :show]].each do |presenter_class, view_name|
    context "in the #{view_name} config" do
      let(:view_config) { config.view_config(view_name) }

      it 'hides a field whose only value is an empty string' do
        expect(rendered_fields(presenter_class, view_config, description_tsim: ['']))
          .not_to include('description_tsim')
      end

      it 'hides a field whose only value is whitespace' do
        expect(rendered_fields(presenter_class, view_config, creator_ssim: ['  ']))
          .not_to include('creator_ssim')
      end

      it 'still renders a field with a value' do
        expect(rendered_fields(presenter_class, view_config, description_tsim: ['A beach.']))
          .to include('description_tsim')
      end
    end
  end

  it 'drops the blank values from a field that also has a real one' do
    document = SolrDocument.new(id: 'abc123', language_ssim: ['', 'English'])
    field = described_class.new(view_context, document, config.index_fields['language_ssim'])
    expect(field.values).to eq(['English'])
  end
end
