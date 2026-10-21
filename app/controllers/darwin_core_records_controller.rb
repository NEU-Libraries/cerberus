# frozen_string_literal: true

# A Work's Darwin Core record: the XML download. See docs/metadata-records.md.
class DarwinCoreRecordsController < ApplicationController
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

  private

    def not_found_label = 'Darwin Core record'
end
