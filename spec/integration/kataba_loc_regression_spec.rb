# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require 'tempfile'

# Live network smoke against the Library of Congress XSD endpoints.
#
# Opt-in: every example skips unless RUN_LOC_SMOKE=1. It exists to catch
# the LoC-specific quirks that broke the XML editor before Kataba 1.1.1:
#
#   * mods-3-N.xsd declared as `http://...` 503s under plain HTTP through
#     LoC's Cloudflare front; the gem must upgrade to HTTPS.
#   * `http://www.loc.gov/mods/xml.xsd` (a vanity URL imported transitively
#     by every mods-3-N.xsd) redirects HTTPS→HTTP and 503s; the gem must
#     rewrite to `/standards/mods/xml.xsd`.
#   * An empty/comments-only mirror_list YAML must not crash `download_xsd`
#     — `YAML.load_file` returns nil, not a Hash.
#
# Run on demand:
#   RUN_LOC_SMOKE=1 bundle exec rspec spec/integration/kataba_loc_regression_spec.rb
describe 'Kataba LoC regression', :loc_smoke do
  before do
    skip 'Set RUN_LOC_SMOKE=1 to run live LoC smoke (network)' unless ENV['RUN_LOC_SMOKE']
  end

  # Isolate each example: ephemeral cache so every fetch exercises the
  # network path, and a nil mirror_list so the project's kataba_mirrors.yml
  # can't silently paper over a gem regression.
  around do |example|
    Dir.mktmpdir do |dir|
      original_storage = Kataba.configuration.offline_storage
      original_mirrors = Kataba.configuration.mirror_list
      Kataba.configuration.offline_storage = dir
      Kataba.configuration.mirror_list = nil
      begin
        example.run
      ensure
        Kataba.configuration.offline_storage = original_storage
        Kataba.configuration.mirror_list = original_mirrors
      end
    end
  end

  # URLs that real MODS records in the repository declare in
  # `xsi:schemaLocation`, plus the transitive `xml.xsd` import every
  # mods-3-N.xsd pulls in via `xs:import`. If any of these regress, the
  # editor's Validate + Preview path goes 500 again.
  {
    'http://www.loc.gov/standards/mods/v3/mods-3-5.xsd' =>
                                                           'mods 3.5 (plain HTTP — must upgrade to HTTPS)',
    'http://www.loc.gov/standards/mods/v3/mods-3-6.xsd' =>
                                                           'mods 3.6 (plain HTTP — must upgrade to HTTPS)',
    'http://www.loc.gov/standards/mods/v3/mods-3-7.xsd' =>
                                                           'mods 3.7 (plain HTTP — must upgrade to HTTPS)',
    'http://www.loc.gov/standards/mods/v3/mods-3-8.xsd' =>
                                                           'mods 3.8 (plain HTTP — must upgrade to HTTPS)',
    'http://www.loc.gov/mods/xml.xsd'                   =>
                                                           'xml.xsd vanity URL (HTTPS→HTTP redirect — must rewrite to /standards/mods/xml.xsd)',
    'http://www.loc.gov/standards/xlink/xlink.xsd'      =>
                                                           'xlink (published HTTP-only — must NOT blanket-upgrade)'
  }.each do |uri, label|
    it "fetches #{label}" do
      expect(Kataba.fetch_schema(uri)).to be_a(Nokogiri::XML::Schema)
    end
  end

  it 'tolerates a comments-only mirror_list YAML (YAML.load_file returns nil)' do
    Tempfile.create(['kataba_mirrors_empty', '.yml']) do |f|
      f.write("---\n# intentionally empty — exercises the nil-load guard\n")
      f.flush
      Kataba.configuration.mirror_list = f.path

      # xlink is the cheapest fetch with no transitive imports — keeps the
      # network cost of this assertion minimal while still exercising the
      # mirror-load codepath.
      expect(Kataba.fetch_schema('http://www.loc.gov/standards/xlink/xlink.xsd'))
        .to be_a(Nokogiri::XML::Schema)
    end
  end
end
