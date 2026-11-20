# frozen_string_literal: true

require 'rails_helper'

# Cerberus overrides Blacklight's base layout for two lines: the stylesheet
# tags, and the CSRF meta tag, which renders only for a signed-in user. A
# Blacklight upgrade that changes anything else in the layout fails here, so
# the override can take the change instead of silently masking it.
RSpec.describe 'layouts/blacklight/base override' do
  def lines(path) = File.readlines(path).map(&:rstrip)

  def normalise(lines, stylesheets:)
    lines.map do |line|
      if line.include?(stylesheets) then :stylesheets
      elsif line.include?('csrf_meta_tags') then :csrf_meta_tags
      else line
      end
    end
  end

  it 'matches the gem layout apart from the stylesheet tags and the CSRF meta tag' do
    ours = lines(Rails.root.join('app/views/layouts/blacklight/base.html.erb'))
           .drop_while { |line| !line.start_with?('<!DOCTYPE') }
    gems = lines(Blacklight::Engine.root.join('app/views/layouts/blacklight/base.html.erb'))

    expect(normalise(ours, stylesheets: 'layout_stylesheet_tags'))
      .to eq(normalise(gems, stylesheets: 'stylesheet_link_tag "application"'))
  end

  it 'gates the CSRF meta tag on a signed-in user' do
    layout = Rails.root.join('app/views/layouts/blacklight/base.html.erb').read

    expect(layout).to include('<%= csrf_meta_tags if user_signed_in? %>')
  end
end
