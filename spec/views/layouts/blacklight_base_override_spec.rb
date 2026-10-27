# frozen_string_literal: true

require 'rails_helper'

# Cerberus overrides Blacklight's base layout for one line: the stylesheet
# tags. A Blacklight upgrade that changes anything else in the layout fails
# here, so the override can take the change instead of silently masking it.
RSpec.describe 'layouts/blacklight/base override' do
  def lines(path) = File.readlines(path).map(&:rstrip)

  it 'matches the gem layout apart from the stylesheet tags' do
    ours = lines(Rails.root.join('app/views/layouts/blacklight/base.html.erb'))
           .drop_while { |line| !line.start_with?('<!DOCTYPE') }
    gems = lines(Blacklight::Engine.root.join('app/views/layouts/blacklight/base.html.erb'))

    expect(ours.map { |line| line.include?('layout_stylesheet_tags') ? :stylesheets : line })
      .to eq(gems.map { |line| line.include?('stylesheet_link_tag "application"') ? :stylesheets : line })
  end
end
