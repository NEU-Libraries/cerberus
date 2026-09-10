# frozen_string_literal: true

require 'rails_helper'

# Guards the WCAG contrast ratios that pin four colour tokens to each other.
#
# The ordinary link colour carries no underline (the `a:not(...)` rule in
# `_layout.scss` removes it), which puts it under two rules at once: 4.5:1
# against every background it sits on, and 3:1 against the surrounding body
# text. Those pull in opposite directions, and the window between them is a few
# thousandths of a unit of relative luminance wide. Every value below is
# load-bearing, and a plausible-looking tweak to any one of them silently breaks
# an audit.
#
# This reads the tokens out of the stylesheet rather than restating them, so the
# next person to change a colour gets a failure naming the constraint.
RSpec.describe 'colour contrast' do
  WHITE = '#ffffff'

  def colors_scss
    @colors_scss ||= Rails.root.join('app/assets/stylesheets/_colors.scss').read
  end

  # WCAG 2.1 relative luminance:
  # https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
  def luminance(hex)
    r, g, b = hex.delete_prefix('#').scan(/../).map do |pair|
      c = pair.to_i(16) / 255.0
      c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
    end
    (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
  end

  def contrast(one, other)
    pair = [luminance(one), luminance(other)]
    (pair.max + 0.05) / (pair.min + 0.05)
  end

  def token(name)
    match = colors_scss.match(/^\$#{Regexp.escape(name)}:\s*(#\h{6})/)
    raise "no $#{name} found in _colors.scss" if match.nil?

    match[1].downcase
  end

  let(:link) { token('link-blue') }
  let(:well) { token('well-bg') }
  let(:page_bg) { token('gray-100') }
  let(:body_text) { token('gray-900') }

  describe 'the link colour against the backgrounds it sits on' do
    it 'clears 4.5:1 on white' do
      expect(contrast(link, WHITE)).to be >= 4.5
    end

    it 'clears 4.5:1 on the page background' do
      expect(contrast(link, page_bg)).to be >= 4.5
    end

    # The darkest background a link sits on, so this is the binding constraint.
    it 'clears 4.5:1 on the .well fill' do
      expect(contrast(link, well)).to be >= 4.5
    end
  end

  describe 'the link colour against surrounding text' do
    # WCAG 1.4.1: with no underline, a link in a block of text is distinguished
    # by colour alone. Restoring the underline would retire this constraint.
    it 'clears 3:1 against body text' do
      expect(contrast(link, body_text)).to be >= 3.0
    end
  end

  describe 'the .well fill' do
    # The panel has no border, so it reads as a panel only by being darker than
    # the page behind it. Lightening it to buy link headroom has a floor.
    it 'stays darker than the page background' do
      expect(luminance(well)).to be < luminance(page_bg)
    end
  end
end
