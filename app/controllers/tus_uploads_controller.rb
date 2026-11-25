# frozen_string_literal: true

# The TUS 1.0.0 resumable-upload endpoint: the core protocol plus the creation
# and termination extensions. The browser sends a large file here in chunks
# ahead of its form, then submits the form with only the upload's id; the
# consuming action claims it through UploadStaging. See docs/uploads.md.
class TusUploadsController < ApplicationController
  VERSION    = '1.0.0'
  EXTENSIONS = 'creation,termination'
  CHUNK_TYPE = 'application/offset+octet-stream'

  # First, so a refusal from any later callback still names the protocol.
  prepend_before_action { response.set_header('Tus-Resumable', VERSION) }
  before_action :require_user
  before_action :require_version, except: :options
  before_action :set_record, only: %i[show update destroy]

  def options
    response.set_header('Tus-Version', VERSION)
    response.set_header('Tus-Extension', EXTENSIONS)
    head :no_content
  end

  # HEAD only: how many bytes have landed, so a client resumes from there.
  def show
    response.set_header('Upload-Offset', @record.offset.to_s)
    response.set_header('Upload-Length', @record.length.to_s)
    response.set_header('Cache-Control', 'no-store')
    head :ok
  end

  def create
    length, filename, filetype = creation_headers
    return head :bad_request if length.nil? || length.negative? || filename.blank?

    record = TusStore.create(length: length, filename: filename, filetype: filetype, owner_id: owner)
    response.set_header('Location', tus_upload_url(record.id))
    response.set_header('Upload-Offset', '0')
    head :created
  end

  def update
    return head :unsupported_media_type unless request.media_type == CHUNK_TYPE

    offset = Integer(request.headers['Upload-Offset'].to_s, 10, exception: false)
    return head :bad_request if offset.nil?

    new_offset = Outage.guard_storage { @record.append(request.body, offset: offset) }
    response.set_header('Upload-Offset', new_offset.to_s)
    head :no_content
  rescue TusStore::OffsetMismatch
    head :conflict
  end

  def destroy
    @record.destroy
    head :no_content
  end

  private

    # The NUID, because a session-built User has no other stable identity. A
    # bare 401 rather than Devise's redirect: the caller is a script, not a page.
    def owner = current_user&.nuid.presence

    def require_user
      head :unauthorized if owner.nil?
    end

    def require_version
      return if request.headers['Tus-Resumable'] == VERSION

      response.set_header('Tus-Version', VERSION)
      head :precondition_failed
    end

    def creation_headers
      metadata = TusStore.parse_metadata(request.headers['Upload-Metadata'])
      [Integer(request.headers['Upload-Length'].to_s, 10, exception: false),
       TusStore.safe_filename(metadata&.dig('filename')), metadata&.dig('filetype')]
    end

    def set_record
      @record = TusStore.find(params[:id], owner_id: owner)
      head :not_found if @record.nil?
    end
end
