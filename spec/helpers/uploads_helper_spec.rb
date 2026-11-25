# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UploadsHelper do
  it 'adds the upload controller beside a form’s own' do
    data = helper.upload_progress_form_data({ controller: 'terms-acceptance', action: 'change->terms-acceptance#sync' })

    expect(data).to include(controller: 'terms-acceptance upload-progress',
                            action:     'change->terms-acceptance#sync submit->upload-progress#submit')
  end

  it 'names the TUS endpoint only for a resumable form' do
    expect(helper.upload_progress_form_data).not_to have_key(:'upload-progress-tus-endpoint-value')
    expect(helper.upload_progress_form_data(resumable: true))
      .to include('upload-progress-tus-endpoint-value': tus_uploads_path)
  end
end
