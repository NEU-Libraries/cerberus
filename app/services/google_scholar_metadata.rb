# frozen_string_literal: true

# Builds the Highwire Press / Google Scholar `<meta>` tag set for a Work show
# page, entirely from the Work's Solr document — no MODS XML parsing on the
# render path (a hard DPS design constraint). Atlas's CitationIndexer projects
# the pieces Scholar needs (creator_ssim / keyword_ssim / pub_date_ssim) onto the
# Work doc; title / abstract / genre already lived there. Public + embargo come
# from the resource permissions the show page already loads.
#
# Emission is gated to public works in the v1 scholarly genres — emitting
# citation_* for a photo or an A/V clip would be noise to Scholar, and v1
# restricted the tags the same way. The view reads the value object and renders
# into `<head>`; URL building (citation_pdf_url) stays in the view, where the
# request host is known.
class GoogleScholarMetadata
  # The v1 three. Only Works whose MODS genre is one of these get citation_* tags.
  SCHOLAR_GENRES = ['Research Publications', 'Technical Reports', 'Theses & Dissertations'].freeze

  # The citation fields Atlas's CitationIndexer projects, plus the already-present
  # abstract — a lean field list so the lookup pulls only what the tags need.
  CITATION_FL = 'genre_ssim,creator_ssim,keyword_ssim,pub_date_ssim,description_tsim'

  # Build for a show page: fetch the work's citation fields from Solr (by noid)
  # and wrap them. A Solr failure degrades to no tags rather than breaking the
  # show page, which otherwise has no Solr dependency.
  def self.for(work:, permissions:, files:)
    doc = Blacklight.default_index.search(
      q: '*:*', fq: [%(alternate_ids_ssim:"id-#{work.id}")], fl: CITATION_FL, rows: 1
    ).documents.first
    new(work: work, permissions: permissions, files: files, solr_doc: doc)
  rescue RSolr::Error
    new(work: work, permissions: permissions, files: files, solr_doc: nil)
  end

  # @param work [AtlasRb::Work] the show page's work (for the display title).
  # @param permissions [#read, #embargo] the resource permissions (AtlasRb), as
  #   loaded by authorize_show! — `read` carries 'public'; `embargo` a date string.
  # @param files [Array<#[]>] the work's assets (AtlasRb::Work.assets).
  # @param solr_doc [#[], nil] the work's Solr document (citation fields).
  def initialize(work:, permissions:, files:, solr_doc:)
    @work = work
    @permissions = permissions
    @files = Array(files)
    @doc = solr_doc || {}
  end

  # Emit citation tags only for a public work in a scholarly genre.
  def emit?
    public? && scholarly_genre?
  end

  delegate :title, to: :@work

  # One citation_author per creator-role name (display form), from the indexer.
  def authors = Array(@doc['creator_ssim'])

  def keywords = Array(@doc['keyword_ssim'])

  def abstract = Array(@doc['description_tsim']).first.presence

  def publication_date = Array(@doc['pub_date_ssim']).first.presence

  # The full-text PDF's blob noid for citation_pdf_url — the first downloadable
  # PDF Blob, and only when the work is publicly downloadable (public + not under
  # embargo). nil suppresses the tag, so we never advertise a private/embargoed
  # file. Returns the noid; the view turns it into an absolute download URL.
  def pdf_blob_noid
    return nil unless public? && !embargoed?

    pdf = @files.find { |asset| asset[:uri].blank? && asset[:mime_type] == 'application/pdf' }
    pdf&.[](:noid)
  end

  private

    def public?
      Array(@permissions&.read).include?('public')
    end

    def scholarly_genre?
      Array(@doc['genre_ssim']).intersect?(SCHOLAR_GENRES)
    end

    # Embargoed iff a release date is set and still in the future (mirrors
    # Transformable#form_preparation's read of the same field).
    def embargoed?
      date = @permissions&.embargo
      return false if date.blank?

      Date.parse(date.to_s) > Date.current
    rescue ArgumentError
      false
    end
end
