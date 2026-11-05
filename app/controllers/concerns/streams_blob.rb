# frozen_string_literal: true

# Streams a Blob's bytes from Atlas into a Live response, and sets the file's
# headers only when the first chunk arrives. Until then the response is
# uncommitted, so a refusal can still render a page. See docs/downloads.md.
module StreamsBlob
  extend ActiveSupport::Concern

  private

    # The block sets the file's headers, once, before the first write. Closing
    # the stream commits the response, so it is closed only once streaming
    # began: closed earlier, the refusal handler would find an empty 200 sent.
    def stream_blob(id, range: nil, &apply_headers)
      started = false
      result = AtlasRb::Blob.content(id, range: range) do |chunk|
        apply_headers.call unless started
        started = true
        response.stream.write(chunk)
      end
      return if started
      return refuse_unstreamed(result[:status]) if refused_status?(result)

      apply_headers.call
      started = true
    ensure
      response.stream.close if started
    end

    def refused_status?(result)
      status = result.is_a?(Hash) ? result[:status] : nil
      !status.nil? && !(200..299).cover?(status)
    end

    def refuse_unstreamed(status)
      case status
      when 403 then render template: 'errors/forbidden', status: :forbidden
      when 404, 410 then render template: 'errors/not_found', status: :not_found, locals: { obj_type: 'file' }
      else head status
      end
    end
end
