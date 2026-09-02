# frozen_string_literal: true

# Builds the Highwire Press / Google Scholar `<meta>` tag set for a Work show
# page. See docs/discovery.md.
#
# Build it from the Work's Solr document alone. Never parse MODS XML on the
# render path.
class GoogleScholarMetadata
  SCHOLAR_GENRES = ['Research Publications', 'Technical Reports', 'Theses & Dissertations'].freeze

  CITATION_FL = 'genre_ssim,creator_ssim,keyword_ssim,pub_date_ssim,description_tsim'

  # A Solr failure degrades to no tags rather than breaking the show page, which
  # otherwise has no Solr dependency.
  def self.for(work:, permissions:, files:)
    doc = Blacklight.default_index.search(
      q: '*:*', fq: [%(alternate_ids_ssim:"id-#{work.id}")], fl: CITATION_FL, rows: 1
    ).documents.first
    new(work: work, permissions: permissions, files: files, solr_doc: doc)
  rescue RSolr::Error
    new(work: work, permissions: permissions, files: files, solr_doc: nil)
  end

  def initialize(work:, permissions:, files:, solr_doc:)
    @work = work
    @permissions = permissions
    @files = Array(files)
    @doc = solr_doc || {}
  end

  def emit?
    public? && scholarly_genre?
  end

  delegate :title, to: :@work

  def authors = Array(@doc['creator_ssim'])

  def keywords = Array(@doc['keyword_ssim'])

  def abstract = Array(@doc['description_tsim']).first.presence

  def publication_date = Array(@doc['pub_date_ssim']).first.presence

  # nil suppresses citation_pdf_url, so the public and not-embargoed guard is
  # what keeps a private or embargoed file from being advertised to Scholar.
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

    def embargoed?
      Embargo.active?(@permissions&.embargo)
    end
end
