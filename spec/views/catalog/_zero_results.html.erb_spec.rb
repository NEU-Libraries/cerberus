# frozen_string_literal: true

require 'rails_helper'

# The calm empty state a blank-query browse falls through to. Its icon is the
# one heading the page, so an empty genre landing shows the genre's own icon.
RSpec.describe 'catalog/_zero_results', type: :view do
  # Blacklight's helpers are absent from a bare view, so verifying partial
  # doubles refuse a stub; define the one the partial asks. The search branch
  # needs the real Blacklight context, so it is covered in
  # spec/requests/sign_in_affordances_spec.rb.
  before { view.define_singleton_method(:search_state) { Struct.new(:filters).new([]) } }

  def render_empty(controller:, genre: nil)
    allow(view).to receive(:controller_name).and_return(controller)
    assign(:genre, genre)
    render partial: 'catalog/zero_results'
  end

  it 'shows an empty genre landing with the genre icon from its heading' do
    render_empty(controller: 'genres', genre: 'Datasets')
    expect(rendered).to have_css('.empty-container-state__icon.fa-database')
  end

  it 'falls back to the bookmark on the bare category browse' do
    render_empty(controller: 'genres')
    expect(rendered).to have_css('.empty-container-state__icon.fa-bookmark')
  end

  it 'shows an empty community with the community icon' do
    render_empty(controller: 'communities')
    expect(rendered).to have_css('.empty-container-state__icon.fa-users')
  end
end
