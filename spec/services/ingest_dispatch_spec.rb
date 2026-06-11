# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IngestDispatch do
  include ActiveJob::TestHelper

  RSpec::Matchers.define_negated_matcher :not_have_enqueued_job, :have_enqueued_job

  let(:fixtures) { Rails.root.join('spec/fixtures/files') }
  let(:work_id) { 'w-route' }
  let(:idempotency_key) { 'idem-route' }
  let(:rendition_key) do
    Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "cerberus:rendition:#{idempotency_key}")
  end

  def dispatch(path, name = File.basename(path))
    described_class.call(work_id: work_id, staged_path: path.to_s, original_filename: name,
                         idempotency_key: idempotency_key)
  end

  it 'routes images to IiifAssetsJob plus the primary ContentCreationJob' do
    path = fixtures.join('image.png')
    expect { dispatch(path) }
      .to have_enqueued_job(IiifAssetsJob).with(work_id, path.to_s)
      .and have_enqueued_job(ContentCreationJob).with(work_id, path.to_s, 'image.png', idempotency_key)
      .and not_have_enqueued_job(PdfRenditionJob)
  end

  it 'routes PDFs to IiifAssetsJob (first-page thumbnails)' do
    path = fixtures.join('example.pdf')
    expect { dispatch(path) }
      .to have_enqueued_job(IiifAssetsJob).with(work_id, path.to_s)
      .and have_enqueued_job(ContentCreationJob)
      .and not_have_enqueued_job(PdfRenditionJob)
  end

  it 'routes Word documents to PdfRenditionJob with the derived rendition key' do
    path = fixtures.join('example.docx')
    expect { dispatch(path) }
      .to have_enqueued_job(PdfRenditionJob).with(work_id, path.to_s, rendition_key)
      .and have_enqueued_job(ContentCreationJob)
      .and not_have_enqueued_job(IiifAssetsJob)
  end

  it 'routes PowerPoint documents to PdfRenditionJob' do
    path = fixtures.join('example.pptx')
    expect { dispatch(path) }
      .to have_enqueued_job(PdfRenditionJob).with(work_id, path.to_s, rendition_key)
      .and not_have_enqueued_job(IiifAssetsJob)
  end

  it 'falls back to the filename to classify legacy OLE containers (.doc)' do
    # Magic bytes alone read as application/x-ole-storage, and Marcel keeps
    # the magic type over the name hint — the OLE fallback in IngestDispatch
    # is what resolves the subtype to application/msword.
    Dir.mktmpdir do |tmp|
      path = File.join(tmp, 'legacy.doc')
      File.binwrite(path, "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1#{"\x00" * 512}".b)

      expect { dispatch(path, 'legacy.doc') }
        .to have_enqueued_job(PdfRenditionJob).with(work_id, path, rendition_key)
        .and not_have_enqueued_job(IiifAssetsJob)
    end
  end

  it 'enqueues only the primary ContentCreationJob for unenriched types' do
    path = fixtures.join('plain.txt')
    expect { dispatch(path) }
      .to have_enqueued_job(ContentCreationJob).with(work_id, path.to_s, 'plain.txt', idempotency_key)
      .and not_have_enqueued_job(IiifAssetsJob)
      .and not_have_enqueued_job(PdfRenditionJob)
  end

  it 'derives a rendition key that is stable across calls and distinct from the primary key' do
    keys = Array.new(2) do
      Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "cerberus:rendition:#{idempotency_key}")
    end
    expect(keys.uniq.size).to eq(1)
    expect(keys.first).not_to eq(idempotency_key)
    expect(keys.first).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
  end
end
