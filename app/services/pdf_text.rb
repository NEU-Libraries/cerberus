# frozen_string_literal: true

# Extracts a PDF's text layer via Ghostscript's `txtwrite` device — the v2
# equivalent of v1's `pdftotext` (the Cerberus image lacks poppler-utils, but
# ships Ghostscript for other rasterization work, so this adds no dependency).
#
# A deliberately thin seam, like WordToPdf: jobs and specs stub this one class
# rather than the `gs` invocation. Like `pdftotext`, this reads the embedded
# text layer only — it is NOT OCR, so an image-only/scanned PDF yields little or
# nothing (v1 had the same limitation). `.available?` lets callers degrade
# gracefully on an image built without Ghostscript.
class PdfText < ApplicationService
  GS_BIN = '/usr/bin/gs'
  TIMEOUT_BIN = '/usr/bin/timeout'
  TIMEOUT_SECONDS = 120

  def self.available?
    File.exist?(GS_BIN)
  end

  def initialize(source_path:)
    @source_path = source_path
  end

  # @return [String, nil] the extracted text (possibly empty for an image-only
  #   PDF), or nil when extraction could not run (missing binary, gs failure, or
  #   the timeout wrapper killing a pathological file). Never raises — full-text
  #   enrichment must never fail a deposit.
  def call
    return nil unless self.class.available?

    Dir.mktmpdir do |dir|
      out = File.join(dir, 'extracted.txt')
      return nil unless run_ghostscript(out) && File.exist?(out)

      File.read(out)
    end
  rescue StandardError => e
    Rails.logger.warn("PdfText: extraction failed for #{@source_path}: #{e.class}: #{e.message}")
    nil
  end

  private

    # -dSAFER sandboxes gs against the untrusted upload; the timeout wrapper
    # bounds a maliciously slow file (mirrors bin/soffice-timeout's posture).
    def run_ghostscript(out)
      cmd = [GS_BIN, '-q', '-dNOPAUSE', '-dBATCH', '-dSAFER',
             '-sDEVICE=txtwrite', "-sOutputFile=#{out}", @source_path]
      cmd = [TIMEOUT_BIN, TIMEOUT_SECONDS.to_s, *cmd] if File.exist?(TIMEOUT_BIN)
      system(*cmd, out: File::NULL, err: File::NULL)
    end
end
