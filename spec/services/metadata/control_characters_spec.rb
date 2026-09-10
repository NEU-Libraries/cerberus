# frozen_string_literal: true

require 'rails_helper'

# Every control character here is built from its codepoint rather than written
# literally, so this file stays pure ASCII on disk. A literal control byte is
# invisible in the editor and the diff of anyone who has to review it.
RSpec.describe Metadata::ControlCharacters do
  def cp(*codepoints) = codepoints.pack('U*')

  let(:vt) { cp(0x000B) } # Word's manual line break (Shift+Enter)
  let(:ff) { cp(0x000C) } # Word's page break (Ctrl+Enter)

  describe '.clean_line' do
    it 'separates the words a Word line break sat between, rather than merging them' do
      expect(described_class.clean_line("Simple#{vt}form VT test")).to eq('Simple form VT test')
    end

    it 'separates on a page break too' do
      expect(described_class.clean_line("Volume one#{ff}Volume two")).to eq('Volume one Volume two')
    end

    it 'drops the controls that carry no meaning' do
      expect(described_class.clean_line("Bell#{cp(0x0007)}Null#{cp(0x0000)}Unit#{cp(0x001F)}")).to eq('BellNullUnit')
    end

    it 'drops the two noncharacters libxml rejects alongside the C0 controls' do
      expect(described_class.clean_line("a#{cp(0xFFFE)}b#{cp(0xFFFF)}c")).to eq('abc')
    end

    it 'leaves tab, newline and carriage return alone -- XML can store all three' do
      expect(described_class.clean_line("a\tb\nc\rd")).to eq("a\tb\nc\rd")
    end

    it 'passes nil straight through, so a MODSMerge field stays untouched' do
      expect(described_class.clean_line(nil)).to be_nil
    end

    # The characters an earlier fuzz confirmed round-trip byte for byte today.
    # Nothing here is XML's problem, so nothing here is this service's business.
    it 'leaves smart punctuation, dashes and the C1 mojibake signature intact' do
      typography = "#{cp(0x201C)}Boston#{cp(0x201D)} #{cp(0x2013)} #{cp(0x2026)}#{cp(0x0092)}#{cp(0x00AD)}"
      expect(described_class.clean_line(typography)).to eq(typography)
    end
  end

  describe '.clean_text' do
    it 'keeps a Word line break as a line break' do
      expect(described_class.clean_text("Para one#{vt}Para two")).to eq("Para one\nPara two")
    end

    it 'passes nil straight through' do
      expect(described_class.clean_text(nil)).to be_nil
    end
  end

  # Why the two differ: a title round-trips through a text input, which cannot
  # hold a newline, so a newline there would change the stored value again on the
  # next save. An abstract round-trips through a textarea, which can.
  it 'maps a separator to a space on one line and a newline in prose' do
    expect(described_class.clean_line("a#{vt}b")).to eq('a b')
    expect(described_class.clean_text("a#{vt}b")).to eq("a\nb")
  end

  describe '.any?' do
    it 'is true for a character XML cannot store' do
      expect(described_class.any?("a#{vt}b")).to be(true)
    end

    it 'is false for text XML can store, however exotic' do
      expect(described_class.any?("a\tb\n#{cp(0x201C)}c#{cp(0x0092)}")).to be(false)
    end

    it 'is false for nil' do
      expect(described_class.any?(nil)).to be(false)
    end
  end

  describe '.report' do
    it 'is nil when there is nothing to report' do
      expect(described_class.report("<mods><title>Fine</title></mods>\n")).to be_nil
    end

    # The message libxml gives for the same input is "PCDATA invalid Char value
    # 11", which names neither the character nor the fix.
    it 'names the character, where it came from, which line it is on, and what to do' do
      xml = "<mods>\n  <title>Simple#{vt}form</title>\n</mods>\n"

      expect(described_class.report(xml))
        .to eq('This document holds a character XML cannot store: U+000B (a manual line break, as Word ' \
               'writes Shift+Enter) on line 2. Replace each one with a line break or a space; deleting ' \
               'it runs the words either side of it together.')
    end

    it 'lists each distinct character once, in reading order' do
      report = described_class.report("a#{ff}\nb#{vt}c#{vt}d\n")

      expect(report).to include('U+000C (a page break, as Word writes Ctrl+Enter) on line 1')
      expect(report).to include('U+000B (a manual line break, as Word writes Shift+Enter) on line 2')
      expect(report.scan('U+000B').size).to eq(1)
      expect(report).to start_with('This document holds characters XML cannot store:')
    end

    it 'reports a control it has no plain name for by codepoint alone' do
      expect(described_class.report("a#{cp(0x0007)}b")).to include('U+0007 on line 1')
    end
  end
end
