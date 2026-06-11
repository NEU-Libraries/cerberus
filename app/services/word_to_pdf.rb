# frozen_string_literal: true

# Converts a Word/PowerPoint document to PDF via LibreOffice (libreconv).
#
# A deliberately thin seam: jobs and specs stub this one class instead of
# libreconv internals. `.available?` lets callers degrade gracefully on
# images built before LibreOffice was added to the Dockerfile — a missing
# binary means "skip the rendition", never a failed deposit.
class WordToPdf < ApplicationService
  # The real binary (not the /usr/bin/soffice shim) — also what the
  # bin/soffice-timeout wrapper execs, so availability of one implies the
  # other works.
  SOFFICE_BIN = '/usr/lib/libreoffice/program/soffice.bin'

  def self.available?
    File.exist?(SOFFICE_BIN)
  end

  def initialize(source_path:, target_path:)
    @source_path = source_path
    @target_path = target_path
  end

  # @raise [Libreconv::ConversionFailedError] on conversion failure or when
  #   the wrapper's 120s timeout kills a hung soffice (exit 124).
  def call
    Libreconv.convert(@source_path, @target_path, Rails.root.join('bin/soffice-timeout').to_s)
    @target_path
  end
end
