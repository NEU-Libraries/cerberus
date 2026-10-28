# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/font_awesome_subset')

RSpec.describe FontAwesomeSubset do
  let(:root) { Rails.root.to_s }

  # A missing glyph renders as nothing, and neither the browser nor the log
  # reports it. This is the only place that does.
  it 'builds every icon the source names' do
    missing = described_class.used_icons(root).keys - described_class.manifest(root).to_a

    expect(missing).to be_empty,
                       "#{missing.join(', ')} not in the served Font Awesome; run bin/fontawesome-subset"
  end

  it 'serves a rule for every icon the source names' do
    served = described_class.icons(Rails.root.join(described_class::TARGET, described_class::STYLESHEET).read)

    expect(served).to include(described_class.used_icons(root))
  end

  describe '.trim' do
    let(:used) { Set['fa-house', 'fa-user'] }

    it 'keeps only the used selectors of an icon rule' do
      css = '.fa-house:before,.fa-home:before{content:"\f015"}.fa-dna:before{content:"\f471"}'

      expect(described_class.trim(css, used)).to eq '.fa-house:before{content:"\f015"}'
    end

    it 'keeps a content rule that is not a plain icon whole' do
      css = '.fa-house:before,.fa-stack:after{content:"\f015"}'

      expect(described_class.trim(css, used)).to eq css
    end

    it 'keeps only the Font Awesome 6 families' do
      six = '@font-face{font-family:"Font Awesome 6 Free";font-weight:900}'
      css = "#{six}@font-face{font-family:\"Font Awesome 5 Free\"}@font-face{font-family:\"FontAwesome\"}"

      expect(described_class.trim(css, used)).to eq six
    end
  end

  describe '.icons' do
    it 'maps every selector of an aliased rule to its codepoint' do
      css = '.fa-house::before,.fa-home:before{content:"\f015"}.fa-0:before{content:"\30"}'

      expect(described_class.icons(css)).to eq('fa-house' => 'f015', 'fa-home' => 'f015', 'fa-0' => '30')
    end

    it 'ignores content rules that are not icons' do
      css = '.fa-stack:after{content:"\f000"}.fa-sr-only{content:""}.x .fa-user:before{content:"\f007"}'

      expect(described_class.icons(css)).to be_empty
    end
  end

  describe '.build' do
    around do |example|
      Dir.mktmpdir do |dir|
        @root = dir
        FileUtils.mkdir_p(["#{dir}/app/views", "#{dir}/#{described_class::UPSTREAM}/css",
                           "#{dir}/#{described_class::TARGET}/css"])
        File.write("#{dir}/app/views/a.haml", '%i.fa-solid.fa-user')
        File.write("#{dir}/#{described_class::UPSTREAM}/#{described_class::STYLESHEET}",
                   '.fa-user:before{content:"\f007"}')
        File.write("#{dir}/#{described_class::TARGET}/#{described_class::STYLESHEET}", 'served')
        File.write("#{dir}/#{described_class::MANIFEST}", "fa-house\n")
        example.run
      end
    end

    def stub_pyftsubset(body)
      path = File.join(@root, 'pyftsubset')
      File.write(path, "#!/bin/sh\n#{body}\n")
      File.chmod(0o755, path)
      path
    end

    def served_css = File.read(File.join(@root, described_class::TARGET, described_class::STYLESHEET))

    # A pyftsubset without brotli fails on the first .woff2, after the CSS and
    # the first .ttf are written.
    it 'leaves the served build and the manifest alone when a font fails' do
      failing = stub_pyftsubset('echo "no brotli" >&2; exit 1')

      expect { described_class.build(@root, pyftsubset: failing) }.to raise_error(/no brotli/)
      expect(served_css).to eq 'served'
      expect(described_class.manifest(@root)).to eq Set['fa-house']
      expect(File).not_to exist("#{@root}/#{described_class::TARGET}.build")
    end

    it 'replaces the served build once every font is cut' do
      working = stub_pyftsubset('for a; do case $a in --output-file=*) : > "${a#--output-file=}";; esac; done')

      described_class.build(@root, pyftsubset: working)

      expect(served_css).to include('.fa-user:before')
      expect(Dir.children("#{@root}/#{described_class::TARGET}/webfonts").size).to eq 6
      expect(described_class.manifest(@root)).to eq Set['fa-user']
      expect(File).not_to exist("#{@root}/#{described_class::TARGET}.build")
    end
  end

  describe '.names' do
    it 'skips compiled assets, which differ between checkouts' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(["#{dir}/app/views", "#{dir}/app/assets/builds"])
        File.write("#{dir}/app/views/a.haml", '%i.fa-solid.fa-user')
        File.write("#{dir}/app/assets/builds/application.css", '.fa-house{}')

        expect(described_class.names(dir)).to eq Set['fa-solid', 'fa-user']
      end
    end
  end
end
