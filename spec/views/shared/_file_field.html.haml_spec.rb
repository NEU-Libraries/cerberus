# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_file_field', type: :view do
  def field(locals = {})
    render(layout: 'shared/file_field', locals: locals) { tag.input(id: 'binary', class: 'file-field__input', type: 'file') }
    Nokogiri::HTML.fragment(rendered).at_css('.file-field')
  end

  it 'wraps the page\'s own input with a Choose file button and an empty-state name' do
    html = field

    expect(html.at_css('.file-field__button').text).to eq('Choose file')
    expect(html.at_css('.file-field__name').text).to eq('No file chosen')
    expect(html.at_css('input#binary[type="file"]')).to be_present
    expect(html['data-controller']).to eq('file-field')
  end

  # The input announces itself through its own label, so the visible copies of
  # its text must not be read a second time.
  it 'hides the button and name text from screen readers' do
    expect(field.css('.file-field__button, .file-field__name').pluck('aria-hidden')).to all(eq('true'))
  end

  it 'takes the small size and an extra class when asked' do
    expect(field(small: true, extra_class: 'mb-3')['class'].split).to include('file-field--sm', 'mb-3')
  end
end
