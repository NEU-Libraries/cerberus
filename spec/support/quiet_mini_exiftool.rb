# frozen_string_literal: true

# mini_exiftool prints "Generating cache file for ExifTool tag names. This takes
# a few seconds but is only needed once..." to STDERR the first time it builds
# its tag-name PStore (see mini_exiftool.rb#load_or_create_pstore). In the suite
# that lands as noise in whichever example first touches Iptc::Extractor.
#
# Warm the cache once, up front, with STDERR silenced — so the (one-time, benign)
# notice never pollutes spec output. After this the class-level PStore is loaded,
# so no example re-triggers the generation.
RSpec.configure do |config|
  config.before(:suite) do
    next unless defined?(MiniExiftool)

    original_stderr = $stderr
    $stderr = File.open(File::NULL, 'w')
    begin
      MiniExiftool.send(:load_or_create_pstore)
    rescue StandardError
      # Best-effort warm-up: never let it break the suite. Worst case the
      # original harmless notice prints during a spec, exactly as before.
      nil
    ensure
      $stderr.close
      $stderr = original_stderr
    end
  end
end
