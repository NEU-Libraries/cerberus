# frozen_string_literal: true

# ZipKit's Rails streaming, except that HEAD sends the archive's headers
# without packing it. Include this, never ZipKit::RailsStreaming directly.
# See docs/head-requests.md.
module StreamsZip
  include ZipKit::RailsStreaming

  def zip_kit_stream(filename: 'download.zip', type: 'application/zip', **, &)
    return super unless request.head?

    send_file_headers!(type:, filename:)
    head :ok
  end
end
