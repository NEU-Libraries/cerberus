# frozen_string_literal: true

# Writes the primary Blob for a staged upload, and — on the batch paths only —
# completes the Work afterwards.
#
# `complete_work:` splits the two kinds of depositor. A batch loader supplies its
# descriptive metadata up front in the manifest, so the ingest finishing IS the
# deposit finishing, and this job completes the Work. An interactive deposit still
# owes a human step: its metadata arrives on the deposit form's second page, so
# completion belongs to that save (ConfirmDepositJob). A Work nobody confirms
# stays in_progress, which is what keeps it out of public discovery and puts it on
# the list of deposits needing attention.
class ContentCreationJob < ApplicationJob
  queue_as :default

  # Both calls are idempotent, so a re-run converges. No block: an exhausted
  # conflict lands in the failed-jobs list. See docs/deposit.md.
  retry_on AtlasRb::StaleResourceError, attempts: 5, wait: :polynomially_longer

  def perform(work_id, source_path, original_filename, idempotency_key, complete_work: true)
    return unless File.exist?(source_path)

    AtlasRb::Blob.create(work_id, source_path, original_filename, idempotency_key: idempotency_key)
    AtlasRb::Work.complete(work_id) if complete_work
  end
end
