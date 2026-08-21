# frozen_string_literal: true

require 'rails_helper'

# One example set, run against both presenters: the point of the module is that
# a heading renders the same whether it is drawn in a result row or on
# Blacklight's document show page.
RSpec.describe EnhancedHeading do
  # A real view context, so the heading travels Blacklight's actual field
  # pipeline rather than a stub of it — the pipeline's escaping is the thing
  # under test.
  let(:view_context) do
    controller = CatalogController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.view_context
  end

  def presenter_for(klass, title, view_config)
    document = SolrDocument.new(id: 'abc123', title_tsim: Array(title))
    klass.new(document, view_context, CatalogController.blacklight_config, view_config: view_config)
  end

  shared_examples 'an enhanced heading' do
    it 'renders a subscript as markup' do
      expect(presenter_for(described_presenter, 'H<sub>2</sub>O', view_config).heading)
        .to eq('H<sub>2</sub>O')
    end

    it 'renders the v1 superconductor title' do
      title = 'Bi<sub>2</sub>Sr<sub>2</sub>CaCu<sub>2</sub>O<sub>8</sub>'
      expect(presenter_for(described_presenter, title, view_config).heading).to eq(title)
    end

    # A tag outside the allowlist shows as source text rather than being tidied
    # away, so a heading never silently loses a character of the record.
    it 'shows a tag outside the allowlist as source text' do
      expect(presenter_for(described_presenter, '<b>Bold</b>', view_config).heading)
        .to eq('&lt;b&gt;Bold&lt;/b&gt;')
    end

    # The reason the parse was narrowed: an HTML parser read "<Tc" as opening an
    # element and discarded the rest of the heading.
    it 'keeps a literal less-than and everything after it' do
      expect(presenter_for(described_presenter, 'Ti <Tc in Bi<sub>2</sub>O', view_config).heading)
        .to eq('Ti &lt;Tc in Bi<sub>2</sub>O')
    end

    it 'returns a heading the view will not escape again' do
      expect(presenter_for(described_presenter, 'H<sub>2</sub>O', view_config).heading).to be_html_safe
    end

    it 'leaves a plain title alone' do
      expect(presenter_for(described_presenter, 'An ordinary title', view_config).heading)
        .to eq('An ordinary title')
    end
  end

  context 'in a result row' do
    let(:described_presenter) { EnhancedIndexPresenter }
    let(:view_config) { CatalogController.blacklight_config.index }

    it_behaves_like 'an enhanced heading'
  end

  context 'on the document show page' do
    let(:described_presenter) { EnhancedShowPresenter }
    # config.show names no title_field, so a Blacklight show-page heading falls
    # back to the document id today. Point the examples at the index field so
    # they exercise the module rather than that configuration gap.
    let(:view_config) { CatalogController.blacklight_config.index }

    it_behaves_like 'an enhanced heading'
  end

  it 'is the presenter Blacklight builds for a result row' do
    expect(CatalogController.blacklight_config.view_config(:list).document_presenter_class)
      .to eq(EnhancedIndexPresenter)
  end

  it 'is the presenter Blacklight builds for a gallery row' do
    expect(CatalogController.blacklight_config.view_config(:gallery).document_presenter_class)
      .to eq(EnhancedIndexPresenter)
  end

  it 'is the presenter Blacklight builds for a document show page' do
    expect(CatalogController.blacklight_config.view_config(:show).document_presenter_class)
      .to eq(EnhancedShowPresenter)
  end
end
