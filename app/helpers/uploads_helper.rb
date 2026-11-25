# frozen_string_literal: true

# Wires a file-upload form to upload_progress_controller.js, which pairs with
# the shared/_upload_progress panel inside the form. See docs/uploads.md.
module UploadsHelper
  # @param data [Hash] the form's own data attributes; its controllers and
  #   actions are kept, and the upload controller is added beside them.
  # @param resumable [Boolean] send the file over TUS ahead of the form. Only
  #   an action that claims `tus_upload_id` through UploadStaging can take it.
  # @param processing_label [String, nil] the panel's label once the bytes are
  #   sent; nil keeps the controller's default.
  # @param processing_note [String, nil] the note beneath it.
  # @return [Hash] data attributes for the form tag.
  def upload_progress_form_data(data = {}, resumable: false, processing_label: nil, processing_note: nil)
    data = data.symbolize_keys
    data.merge(
      controller:                               [data[:controller], 'upload-progress'].compact.join(' '),
      action:                                   [data[:action], 'submit->upload-progress#submit'].compact.join(' '),
      'upload-progress-tus-endpoint-value':     (tus_uploads_path if resumable),
      'upload-progress-processing-label-value': processing_label,
      'upload-progress-processing-note-value':  processing_note
    ).compact
  end
end
