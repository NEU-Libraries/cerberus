# frozen_string_literal: true

# Projects a multipage Work's ordered page listing into a IIIF
# Presentation 3.0 Manifest: one Canvas per page FileSet that carries an
# image-service Delegate, in page order. Pure read-time projection — the
# only persisted fact is each page's service pointer (minted at ingest by
# MultipageIngestJob); sizes, tiles and zoom all derive from the image
# server on demand.
#
# Canvas dimensions come from each service's `info.json`, fetched once and
# cached indefinitely — a page's JP2 is immutable, so its dimensions are
# too (a re-mint gets a new identifier and so a new cache key). Pages
# whose service or info.json is unavailable are skipped rather than
# failing the whole manifest: a partially-zoomable book beats a 500.
class IiifManifest < ApplicationService
  CONTEXT = 'http://iiif.io/api/presentation/3/context.json'

  # @param work [Hash] the AtlasRb::Work response (title riding on it).
  # @param pages [Array<Hash>] AtlasRb::Work.file_sets entries, page order.
  # @param url [String] this manifest's own canonical URL (its IIIF id).
  def initialize(work:, pages:, url:)
    @work = work
    @pages = pages
    @url = url
  end

  def call
    {
      '@context' => CONTEXT,
      'id'       => @url,
      'type'     => 'Manifest',
      'label'    => { 'none' => [@work['title'].presence || @work['id']] },
      'items'    => canvases
    }
  end

  private

    def canvases
      @pages.filter_map do |page|
        service = Array(page['assets']).find { |asset| asset['uri'].present? }&.[]('uri')
        next if service.blank?

        size = dimensions(service)
        next if size.blank?

        canvas(page, service, size)
      end
    end

    def canvas(page, service, size)
      id = "#{@url}/canvas/#{page['noid']}"
      {
        'id' => id, 'type' => 'Canvas',
        'label' => { 'none' => [page['position'].to_s] },
        'width' => size['width'], 'height' => size['height'],
        'items' => [{
          'id' => "#{id}/page", 'type' => 'AnnotationPage',
          'items' => [painting(id, service, size)]
        }]
      }
    end

    def painting(canvas_id, service, size)
      {
        'id' => "#{canvas_id}/annotation", 'type' => 'Annotation',
        'motivation' => 'painting', 'target' => canvas_id,
        'body' => {
          'id' => "#{service}/full/max/0/default.jpg",
          'type' => 'Image', 'format' => 'image/jpeg',
          'width' => size['width'], 'height' => size['height'],
          'service' => [{ 'id' => service, 'type' => 'ImageService3', 'profile' => 'level2' }]
        }
      }
    end

    def dimensions(service)
      Rails.cache.fetch(['iiif-info', service]) do
        response = Faraday.get("#{service}/info.json")
        response.success? ? JSON.parse(response.body).slice('width', 'height') : nil
      end
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.warn("IiifManifest: info.json unavailable for #{service} (#{e.message})")
      nil
    end
end
