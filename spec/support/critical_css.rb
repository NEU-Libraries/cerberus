# frozen_string_literal: true

# Pages render with the blocking stylesheet links unless an example is tagged
# :critical_css. The inline CSS carries class names, numbers and words such as
# "Courier New", so a whole-body `include` could match the stylesheet instead of
# the markup it means to check. See docs/critical-css.md.
RSpec.configure do |config|
  config.before do |example|
    allow(CriticalCss).to receive(:for).and_return(nil) unless example.metadata[:critical_css]
  end
end
