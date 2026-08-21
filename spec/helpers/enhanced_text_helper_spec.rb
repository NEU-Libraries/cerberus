# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnhancedTextHelper, type: :helper do
  # The v1 title this feature exists for: a MODS record escapes the tags into
  # the title's text node, so the string that reaches a view holds them raw.
  SUPERCONDUCTOR = 'Origin of the high-energy kink in the photoemission spectrum of the ' \
                   'high-temperature superconductor Bi<sub>2</sub>Sr<sub>2</sub>CaCu<sub>2</sub>O<sub>8</sub>'

  describe '#enhanced_text' do
    it 'renders a subscript as markup' do
      expect(helper.enhanced_text(SUPERCONDUCTOR))
        .to include('Bi<sub>2</sub>Sr<sub>2</sub>CaCu<sub>2</sub>O<sub>8</sub>')
    end

    it 'renders a superscript as markup' do
      expect(helper.enhanced_text('Ca<sup>2+</sup> transport')).to eq('Ca<sup>2+</sup> transport')
    end

    it 'returns a string the view will not escape again' do
      expect(helper.enhanced_text('H<sub>2</sub>O')).to be_html_safe
    end

    it 'drops a tag outside the allowlist' do
      expect(helper.enhanced_text('<b>Bold</b> and <sub>2</sub>')).to eq('Bold and <sub>2</sub>')
    end

    # The tag goes; the text it wrapped survives as inert characters, which is
    # what Rails' allowlist sanitizer does with any tag outside the list. That
    # is the property worth pinning: nothing executable and nothing escaped
    # back into markup, even though a curator who pastes a script tag sees its
    # source as text.
    it 'leaves no script element behind' do
      html = helper.enhanced_text('<script>alert(1)</script>Title')

      expect(html).not_to include('<script')
      expect(html).to eq('alert(1)Title')
    end

    it 'refuses an attribute on an allowed tag' do
      html = helper.enhanced_text('<sub onmouseover="alert(1)" style="color:red">2</sub>')
      expect(html).to eq('<sub>2</sub>')
    end

    it 'escapes a less-than that is not a tag' do
      expect(helper.enhanced_text('Cases where a < b')).to eq('Cases where a &lt; b')
    end

    it 'escapes an ampersand' do
      expect(helper.enhanced_text('Ford &amp; Sons')).to eq('Ford &amp; Sons')
    end

    it 'leaves a title with no markup alone' do
      expect(helper.enhanced_text('An ordinary title')).to eq('An ordinary title')
    end

    it 'handles nil' do
      expect(helper.enhanced_text(nil)).to eq('')
    end
  end

  describe '#plain_text' do
    it 'strips a subscript rather than escaping it' do
      expect(helper.plain_text('H<sub>2</sub>O')).to eq('H2O')
    end

    it 'strips the whole superconductor title down to readable text' do
      expect(helper.plain_text(SUPERCONDUCTOR)).to end_with('Bi2Sr2CaCu2O8')
    end

    it 'decodes an ampersand rather than leaving it escaped' do
      expect(helper.plain_text('Ford &amp; Sons')).to eq('Ford & Sons')
    end

    # The value is meant to be interpolated, so it must not arrive pre-escaped:
    # a second escape would print the entity itself.
    it 'returns an ordinary string, not html_safe output' do
      expect(helper.plain_text('H<sub>2</sub>O')).not_to be_html_safe
    end

    it 'handles nil' do
      expect(helper.plain_text(nil)).to eq('')
    end

    # A title is free text, and "<" is a character a physics title uses for its
    # own sake — MODS holding `&lt;Tc` yields the text `<Tc`. An HTML parser
    # treats the two spacings differently: "< T" cannot open a tag, "<T" can.
    it 'keeps a spaced less-than that means less-than' do
      expect(helper.plain_text('Superconductivity at Ti < Tc')).to eq('Superconductivity at Ti < Tc')
    end

    # KNOWN LIMITATION, pinned rather than endorsed: an unspaced less-than reads
    # as a tag, and the element it opens swallows everything up to the next ">".
    # Both helpers share it, because both hand the string to an HTML parser that
    # resolves the ambiguity toward markup.
    it 'drops the text after an unspaced less-than' do
      expect(helper.plain_text('Superconductivity at Ti <Tc')).to eq('Superconductivity at Ti ')
      expect(helper.enhanced_text('Superconductivity at Ti <Tc')).to eq('Superconductivity at Ti ')
    end

    # The damage is a span, not a tail, and its size depends on where the next
    # ">" falls — here that is the subscript's own closing bracket, so a valid
    # subscript is destroyed too and the "2" survives as bare text. This is the
    # example the Atlas fix is written against, so it is the one to watch: it
    # flips the day the parse is narrowed to the allowlist.
    it 'lets an unspaced less-than swallow a following subscript' do
      expect(helper.enhanced_text('Ti <Tc in Bi<sub>2</sub>O')).to eq('Ti 2O')
    end
  end

  describe 'truncating through #plain_text' do
    # "Bi<sub>2</sub>Sr<sub>2</sub>" is 28 characters of string but 6 of text,
    # so the limit has to be measured after the markup comes off.
    it 'measures the visible text, not the markup' do
      stripped = helper.plain_text('Bi<sub>2</sub>Sr<sub>2</sub>')

      expect(stripped).to eq('Bi2Sr2')
      expect(helper.truncate(stripped, length: 5)).to eq('Bi...')
    end
  end
end
