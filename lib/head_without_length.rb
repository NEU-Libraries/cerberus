# frozen_string_literal: true

# Keeps Puma from announcing `Content-Length: 0` on a HEAD response. Rack::Head
# swaps the body for an empty array, and Puma sizes an array body, so every
# HEAD claimed to describe an empty resource. HTTP forbids a length that GET
# would not send. A body Puma cannot size makes it send no length at all, and a
# Content-Length the app set itself, as media does, still goes out unchanged.
# See docs/head-requests.md.
class HeadWithoutLength
  # Responds to #each only: no #to_ary, #to_path or #size for Puma to measure.
  class UnsizedEmptyBody
    def each; end
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    return [status, headers, body] unless env['REQUEST_METHOD'] == 'HEAD'

    body.close if body.respond_to?(:close)
    [status, headers, UnsizedEmptyBody.new]
  end
end
