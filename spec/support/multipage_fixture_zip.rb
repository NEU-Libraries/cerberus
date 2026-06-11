# frozen_string_literal: true

require 'zip'

# The multipage fixtures are committed unwrapped (readable in the repo);
# specs zip a fixture dir into tmp on demand to exercise the real archive
# path. WSL `*:Zone.Identifier` ADS cruft is excluded so presence checks
# and extraction sets stay clean.
module MultipageFixtureZip
  # Zipping the multi-MB page TIFFs is slow enough to matter per-example,
  # and specs only read the archives — so cache one zip per fixture dir for
  # the process. Specs that mutate a staged copy (e.g. deleting the
  # manifest) cp it first, so the cache stays pristine.
  CACHE = {} # rubocop:disable Style/MutableConstant

  def zip_multipage_fixture(dir_name)
    CACHE[dir_name] ||= begin
      src = Rails.root.join('spec/fixtures/files', dir_name)
      out = File.join(Dir.mktmpdir('multipage-fixture'), "#{dir_name}.zip")
      Zip::File.open(out, create: true) do |zip|
        Dir.children(src).reject { |f| f.end_with?('Zone.Identifier') }.sort.each do |f|
          zip.add(f, src.join(f).to_s)
        end
      end
      out
    end
  end
end

RSpec.configure { |config| config.include MultipageFixtureZip }
