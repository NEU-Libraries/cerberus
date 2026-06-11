# frozen_string_literal: true

# Per-page multipage loader job. One is enqueued per page row by
# MultipageUnzipJob, after the whole archive has validated and the one
# shared Work is minted (work_pid rides on the ingest row, so the row id
# is the only argument).
#
# Each page becomes an ordered FileSet (position = the manifest Sequence)
# holding the page binary as its Blob. Page jobs run in parallel safely —
# every job touches only its own FileSet.
#
# Retry safety is the design center. The two Atlas writes differ:
#
# - FileSet.create is idempotent (ingest.idempotency_key) and its result
#   is stamped on file_set_pid, so a retry skips or converges the create.
# - FileSet.update (the binary PATCH) APPENDS a new Blob on every call.
#   blob_attached_at is stamped right after a successful PATCH; on resumed
#   executions only (file_set_pid was already set when the job started —
#   i.e. a previous attempt got past create), Atlas is consulted before
#   PATCHing so a lost response can't double-attach the page. The happy
#   path makes zero extra reads.
#
# Page 1 also seeds the WORK-level thumbnails via the existing
# IiifAssetsJob (it self-guards on an existing thumbnail). Per-page IIIF
# derivatives are deliberately absent — they need a FileSet-level
# derivative endpoint Atlas doesn't expose yet (see the per-FileSet
# derivatives addendum gap report). ContentCreationJob is never enqueued
# here: it calls Work.complete, which is CompleteWorkJob's job, exactly
# once, after every page has landed.
class MultipageIngestJob < ApplicationJob
  queue_as :default

  retry_on StandardError, attempts: 3, wait: :polynomially_longer do |job, exception|
    ingest = MultipageIngest.find_by(id: job.arguments.first)
    next if ingest.nil? || ingest.completed? || ingest.completed_with_warnings? || ingest.failed?

    ingest.update!(
      status:        :failed,
      error_message: "Failed after #{job.executions} attempts (#{exception.class}: #{exception.message})"
    )
    ingest.load_report&.maybe_finalize!
  end

  def perform(multipage_ingest_id)
    ingest = MultipageIngest.find(multipage_ingest_id)
    return if terminal?(ingest)
    # The unzip job structurally failed the report (e.g. a sibling page's
    # archive went missing mid-extract) — don't keep building onto a Work
    # the report has already given up on.
    return if ingest.load_report.failed?

    ingest.update!(status: :processing)

    staged = stage_page(ingest)
    if staged.nil?
      return finalize_failure(ingest, "Page file '#{ingest.source_filename}' was not found in the archive.")
    end

    resumed = ingest.file_set_pid.present?
    ensure_file_set!(ingest)
    attach_blob!(ingest, staged, verify: resumed)

    IiifAssetsJob.perform_later(ingest.work_pid, staged) if ingest.sequence == 1
    finalize_success(ingest)
  end

  private

    def terminal?(ingest)
      ingest.completed? || ingest.completed_with_warnings? || ingest.failed?
    end

    def uploads_root
      Rails.application.config.x.cerberus.uploads_root
    end

    # Move the extracted page under uploads_root/<work_pid>/ (same-FS
    # rename, streaming copy across FS — never read+write). A dest that
    # already exists means a previous attempt staged it; reuse it, since
    # the mv may have consumed the extracted source.
    def stage_page(ingest)
      dir = File.join(uploads_root, ingest.work_pid.to_s)
      FileUtils.mkdir_p(dir)
      dest = File.join(dir, ingest.source_filename)
      return dest if File.exist?(dest)

      source = File.join(XmlLoader::Paths.extracted_dir(ingest.load_report), ingest.source_filename)
      return nil unless File.exist?(source)

      FileUtils.mv(source, dest)
      dest
    end

    def ensure_file_set!(ingest)
      return if ingest.file_set_pid.present?

      file_set = AtlasRb::FileSet.create(ingest.work_pid, 'image',
                                         position:        ingest.sequence,
                                         idempotency_key: ingest.idempotency_key)
      ingest.update!(file_set_pid: file_set.id)
    end

    def attach_blob!(ingest, staged, verify:)
      return if ingest.blob_attached_at.present?
      return ingest.update!(blob_attached_at: Time.current) if verify && file_set_has_content?(ingest)

      AtlasRb::FileSet.update(ingest.file_set_pid, staged)
      ingest.update!(blob_attached_at: Time.current)
    end

    # Only consulted on resumed executions: did a previous attempt's PATCH
    # land without being recorded (crash or lost response after the server
    # processed it)? Key asymmetry is deliberate — FileSet.create returns
    # the noid under "id", the Work.file_sets listing under "noid".
    def file_set_has_content?(ingest)
      entry = AtlasRb::Work.file_sets(ingest.work_pid).find { |fs| fs['noid'] == ingest.file_set_pid }
      entry.present? && entry['assets'].present?
    end

    def finalize_success(ingest)
      ingest.update!(status: :completed)
      ingest.load_report.maybe_finalize!
    end

    def finalize_failure(ingest, error_message)
      ingest.update!(status: :failed, error_message: error_message)
      ingest.load_report.maybe_finalize!
    end
end
