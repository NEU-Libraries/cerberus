# frozen_string_literal: true

# A Work's Darwin Core record: the XML download, and the edit page's upload and
# removal. See docs/metadata-records.md.
class DarwinCoreRecordsController < ApplicationController
  # The edit page shows this many validation errors at most. A wrong file can
  # break hundreds of schema rules, and the flash rides the session row.
  MAX_ERRORS = 10

  NO_FILE   = 'Choose a Darwin Core XML file to upload.'
  NOT_SAVED = 'The Darwin Core record was not saved. Fix the errors in the file and upload it again.'
  SAVED     = 'Darwin Core record saved.'
  REMOVED   = 'Darwin Core record removed.'

  before_action :authorize_edit!, only: %i[update destroy]

  # The show page's own gates, in its order, so the file downloads exactly
  # where the tab shows: gone when tombstoned, refused when unreadable, and
  # hidden while the deposit is unfinished.
  def show
    work = require_resource!(AtlasRb::Work.find(params[:id]))
    return render_gone(work) if work.tombstoned

    authorize_show!
    deny_if_unfinished!(work)
    xml = require_resource!(AtlasRb::Work.dwc(params[:id], 'xml'))
    send_data xml, type: 'application/xml', disposition: 'attachment', filename: "#{params[:id]}-darwin-core.xml"
  end

  # A PUT replaces the whole record, so uploading the same file twice is safe.
  def update
    file = params[:dwc_file]
    return back_to_tab(alert: NO_FILE) if file.blank?

    errors = DarwinCoreRecordValidator.call(xml: File.read(file.path))
    return refused(errors.first(MAX_ERRORS).map(&:to_s)) if errors.any?

    AtlasRb::Resource.put_dwc(params[:id], file.path, origin: 'dwc_upload')
    back_to_tab(notice: SAVED)
  rescue AtlasRb::ResourceError => e
    # Atlas repeats the shape checks and answers 422; anything else is not a
    # refusal of this document, so it keeps the shared handling.
    raise unless e.status == 422

    refused([e.message])
  end

  # A withdrawal, not a purge: Atlas keeps the record's history, and the next
  # upload restores it.
  def destroy
    AtlasRb::Resource.delete_dwc(params[:id])
    back_to_tab(notice: REMOVED)
  end

  private

    def not_found_label = 'Darwin Core record'

    # The layout renders only the standard flash keys, so the pane renders
    # dwc_errors itself.
    def refused(errors)
      back_to_tab(alert: NOT_SAVED, dwc_errors: errors)
    end

    # A query param, not a fragment, because Turbo drops the fragment when it
    # follows a redirect.
    def back_to_tab(flash_values)
      redirect_to edit_work_path(params[:id], tab: 'darwin-core'), flash: flash_values
    end
end
