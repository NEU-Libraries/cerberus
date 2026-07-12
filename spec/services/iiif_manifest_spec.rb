# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IiifManifest do
  let(:work) { { 'id' => 'w-1', 'title' => 'Field Notebook' } }
  let(:url)  { 'http://example.test/works/w-1/manifest' }

  let(:pages) do
    [
      { 'noid' => 'p-1', 'position' => 1,
        'assets' => [{ 'noid' => 'b-1' }, { 'uri' => 'https://iiif.test/iiif/3/one.jp2' }] },
      { 'noid' => 'p-2', 'position' => 2,
        'assets' => [{ 'noid' => 'b-2' }] }, # no service pointer — skipped
      { 'noid' => 'p-3', 'position' => 3,
        'assets' => [{ 'uri' => 'https://iiif.test/iiif/3/three.jp2' }] }
    ]
  end

  before do
    # Default to the ungated case (no signing secret) so these tests don't depend
    # on the ambient env; the signing test overrides it.
    allow(Rails.application.config.x.cerberus).to receive(:iiif_signing_secret).and_return(nil)
    allow(Faraday).to receive(:get) do |info_url|
      instance_double(Faraday::Response, success?: true,
                                         body:     { width: 2000, height: 3000, id: info_url }.to_json)
    end
  end

  def manifest = described_class.call(work: work, pages: pages, url: url)

  it 'projects a Presentation 3.0 manifest with one canvas per service-bearing page, in order' do
    expect(manifest['@context']).to eq('http://iiif.io/api/presentation/3/context.json')
    expect(manifest['id']).to eq(url)
    expect(manifest['label']).to eq('none' => ['Field Notebook'])
    expect(manifest['items'].pluck('id'))
      .to eq(["#{url}/canvas/p-1", "#{url}/canvas/p-3"])
  end

  it 'paints each canvas with the image service and its real dimensions' do
    canvas = manifest['items'].first
    expect(canvas).to include('width' => 2000, 'height' => 3000)

    body = canvas.dig('items', 0, 'items', 0, 'body')
    expect(body['id']).to eq('https://iiif.test/iiif/3/one.jp2/full/max/0/default.jpg')
    expect(body['service']).to contain_exactly(
      hash_including('id' => 'https://iiif.test/iiif/3/one.jp2', 'type' => 'ImageService3')
    )
  end

  it 'skips a page whose info.json is unreachable rather than failing the manifest' do
    allow(Faraday).to receive(:get).with('https://iiif.test/iiif/3/one.jp2/info.json')
                                   .and_raise(Faraday::ConnectionFailed.new('down'))
    allow(Faraday).to receive(:get).with('https://iiif.test/iiif/3/three.jp2/info.json').and_return(
      instance_double(Faraday::Response, success?: true, body: { width: 100, height: 200 }.to_json)
    )

    expect(manifest['items'].pluck('id')).to eq(["#{url}/canvas/p-3"])
  end

  it 'renders an empty manifest for a work with no deep-zoomable pages' do
    no_service = described_class.call(work: work, pages: [pages[1]], url: url)
    expect(no_service['items']).to eq([])
  end

  it 'signs the server-side info.json read when a signing secret is configured' do
    allow(Rails.application.config.x.cerberus).to receive(:iiif_signing_secret).and_return('s3cret')
    fetched = []
    allow(Faraday).to receive(:get) do |info_url|
      fetched << info_url
      instance_double(Faraday::Response, success?: true, body: { width: 10, height: 20 }.to_json)
    end

    manifest

    expect(fetched).to all(match(%r{/info\.json\?exp=\d+&sig=\h+\z}))
  end

  it 'embeds a per-image token in the browser-facing service id when signing is on' do
    allow(Rails.application.config.x.cerberus).to receive(:iiif_signing_secret).and_return('s3cret')

    body = manifest['items'].first.dig('items', 0, 'items', 0, 'body')
    service_id = body['service'].first['id']

    expect(service_id).to match(%r{\Ahttps://iiif\.test/iiif/3/\d+~\h{64}~one\.jp2\z})
    expect(body['id']).to eq("#{service_id}/full/max/0/default.jpg")
  end
end
