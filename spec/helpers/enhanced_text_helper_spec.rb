# frozen_string_literal: true

require 'rails_helper'

# The contract here is shared with Atlas's EnhancedText: Atlas renders the MODS
# metadata block that sits directly under these headings, so the two must agree
# character for character. Where an example looks oddly specific, it is because
# Atlas asserts the same string.
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

    it 'case-folds an upper-case tag' do
      expect(helper.enhanced_text('<SUB>2</SUB>')).to eq('<sub>2</sub>')
    end

    it 'leaves a title with no markup alone' do
      expect(helper.enhanced_text('An ordinary title')).to eq('An ordinary title')
    end

    it 'handles nil' do
      expect(helper.enhanced_text(nil)).to eq('')
    end

    # The defect this replaced an HTML parser to fix. A parser reads a bare "<"
    # before a letter as opening an element and discards everything to the next
    # ">", so the third example here used to render as "Ti 2O" — the span gone
    # and the subscript with it.
    describe 'a literal less-than' do
      it 'survives when spaced' do
        expect(helper.enhanced_text('Cases where a < b')).to eq('Cases where a &lt; b')
      end

      it 'survives when unspaced' do
        expect(helper.enhanced_text('Resistivity at Ti <Tc')).to eq('Resistivity at Ti &lt;Tc')
      end

      it 'cannot swallow a following subscript' do
        expect(helper.enhanced_text('Ti <Tc in Bi<sub>2</sub>O')).to eq('Ti &lt;Tc in Bi<sub>2</sub>O')
      end

      it 'cannot swallow a span when both spacings appear' do
        expect(helper.enhanced_text('Resistivity at Ti <Tc and Ti < Tc in Bi<sub>2</sub>O'))
          .to eq('Resistivity at Ti &lt;Tc and Ti &lt; Tc in Bi<sub>2</sub>O')
      end
    end

    describe 'what it refuses to render' do
      # A tag outside the allowlist shows as source text rather than being
      # tidied away. Every character of the curator's value survives, and the
      # mistake is visible so the record can be fixed.
      it 'shows a tag outside the allowlist as source text' do
        expect(helper.enhanced_text('a <b>bold</b> claim')).to eq('a &lt;b&gt;bold&lt;/b&gt; claim')
      end

      it 'shows a script tag as source text and executes nothing' do
        expect(helper.enhanced_text('<script>alert(1)</script>Title'))
          .to eq('&lt;script&gt;alert(1)&lt;/script&gt;Title')
      end

      # Only a BARE tag is revived, so an attribute cannot round-trip at all.
      # The unmatched </sub> left behind is inert — a browser ignores a stray
      # end tag — and this is the same string Atlas's decorator emits.
      it 'refuses to revive an allowed tag carrying an attribute' do
        expect(helper.enhanced_text('H<sub class="x">2</sub>O'))
          .to eq('H&lt;sub class="x"&gt;2</sub>O')
      end

      it 'does not revive a tag that was already escaped in the value' do
        expect(helper.enhanced_text('already &lt;sub&gt; escaped'))
          .to eq('already &amp;lt;sub&amp;gt; escaped')
      end
    end

    it 'escapes an ampersand' do
      expect(helper.enhanced_text('Ford & Sons')).to eq('Ford &amp; Sons')
    end

    # An apostrophe or a quote is ordinary in a title and only needs escaping
    # inside an attribute value, which this output never is.
    it 'leaves the quote characters alone' do
      expect(helper.enhanced_text(%q(What's "New"))).to eq(%q(What's "New"))
    end
  end

  describe '#plain_text' do
    it 'strips a subscript rather than escaping it' do
      expect(helper.plain_text('H<sub>2</sub>O')).to eq('H2O')
    end

    it 'strips the whole superconductor title down to readable text' do
      expect(helper.plain_text(SUPERCONDUCTOR)).to end_with('Bi2Sr2CaCu2O8')
    end

    it 'strips an allowed tag even when it carries an attribute' do
      expect(helper.plain_text('H<sub class="x">2</sub>O')).to eq('H2O')
    end

    it 'handles nil' do
      expect(helper.plain_text(nil)).to eq('')
    end

    # The value is meant to be interpolated or handed to `tag.meta`, so it must
    # not arrive pre-escaped: a second escape would print the entity itself.
    it 'returns an ordinary string, not html_safe output' do
      expect(helper.plain_text('H<sub>2</sub>O')).not_to be_html_safe
    end

    it 'leaves an ampersand as itself for the caller to escape once' do
      expect(helper.plain_text('Ford & Sons')).to eq('Ford & Sons')
    end

    # Same defect, same fix: removal is by pattern, so a literal less-than is
    # not a tag and nothing after it is lost.
    it 'keeps a literal less-than in either spacing' do
      expect(helper.plain_text('Superconductivity at Ti < Tc')).to eq('Superconductivity at Ti < Tc')
      expect(helper.plain_text('Superconductivity at Ti <Tc')).to eq('Superconductivity at Ti <Tc')
    end

    it 'leaves a tag outside the allowlist for the caller to escape' do
      expect(helper.plain_text('a <b>bold</b> claim')).to eq('a <b>bold</b> claim')
    end
  end

  # The two rules here are Atlas's, verified against its decorator on a live
  # record: a blank line breaks a paragraph, a lone newline is a wrap. A Work's
  # show page renders its abstract through Atlas and a container's renders the
  # same stored value through this helper, so a disagreement shows up as one
  # description laid out two ways.
  describe '#enhanced_paragraphs' do
    it 'breaks a paragraph on a blank line' do
      expect(helper.enhanced_paragraphs("First para.\n\nSecond para."))
        .to eq('<p>First para.</p><p>Second para.</p>')
    end

    it 'treats a lone newline as a wrap, not a break' do
      expect(helper.enhanced_paragraphs("Line A.\nLine B.")).to eq('<p>Line A. Line B.</p>')
    end

    it 'collapses a run of blank lines into one break' do
      expect(helper.enhanced_paragraphs("One.\n\n\n\nTwo.")).to eq('<p>One.</p><p>Two.</p>')
    end

    it 'ignores the trailing spaces a textarea collects on a blank line' do
      expect(helper.enhanced_paragraphs("One.\n   \nTwo.")).to eq('<p>One.</p><p>Two.</p>')
    end

    it 'wraps a single paragraph, matching what Atlas emits for one abstract' do
      expect(helper.enhanced_paragraphs('Just the one.')).to eq('<p>Just the one.</p>')
    end

    it 'keeps enhanced markup inside a paragraph' do
      expect(helper.enhanced_paragraphs("H<sub>2</sub>O.\n\nAnd more."))
        .to eq('<p>H<sub>2</sub>O.</p><p>And more.</p>')
    end

    it 'escapes a tag outside the allowlist rather than emitting it' do
      expect(helper.enhanced_paragraphs('a <b>bold</b> claim'))
        .to eq('<p>a &lt;b&gt;bold&lt;/b&gt; claim</p>')
    end

    it 'renders nothing for a blank value rather than an empty paragraph' do
      expect(helper.enhanced_paragraphs(nil)).to eq('')
      expect(helper.enhanced_paragraphs("\n\n")).to eq('')
    end

    it 'returns a string the view will not escape again' do
      expect(helper.enhanced_paragraphs('Plain.')).to be_html_safe
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
