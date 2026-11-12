# frozen_string_literal: true

# Builds the Highwire Press / Google Scholar `<meta>` tag set for a Work show
# page from the Work's CSL-JSON citation. See docs/discovery.md.
class GoogleScholarMetadata
  # The CSL types Atlas assigns to the scholarly genres. Atlas owns the genre
  # rule, so a genre it maps to one of these emits tags.
  SCHOLAR_TYPES = %w[thesis report article].freeze

  def self.public?(permissions)
    Array(permissions&.read).include?('public')
  end

  # Runs as a task in WorksController#parallel_show_reads, which re-raises a
  # task's error. The rescue lives here so a failed read means no tags rather
  # than a failed show page.
  def self.citation_for(id)
    AtlasRb::Work.citation(id)
  rescue StandardError => e
    Rails.logger.error("GoogleScholarMetadata: citation read failed for #{id}: #{e.class} #{e.message}")
    nil
  end

  def initialize(citation:, permissions:, files:)
    @citation = citation || {}
    @permissions = permissions
    @files = Array(files)
  end

  def emit?
    public? && SCHOLAR_TYPES.include?(@citation['type'])
  end

  def title = @citation['title']

  def authors = Array(@citation['author']).filter_map { |name| name['literal'].presence }

  # CSL joins the subjects into one string, which is the shape the keywords tag
  # takes, so it passes through rather than being split on a comma a subject
  # can itself contain.
  def keywords = @citation['keyword'].presence

  def abstract = @citation['abstract'].presence

  # The year alone. A date the record could not encode arrives as `literal`,
  # with no parts, and gives no tag.
  def publication_date = @citation['issued']&.dig('date-parts', 0, 0)&.to_s

  # nil suppresses citation_pdf_url, so the public and not-embargoed guard is
  # what keeps a private or embargoed file from being advertised to Scholar.
  def pdf_blob_noid
    return nil unless public? && !embargoed?

    pdf = @files.find { |asset| AssetKind.blob?(asset) && asset[:mime_type] == 'application/pdf' }
    pdf&.[](:noid)
  end

  private

    def public?
      self.class.public?(@permissions)
    end

    def embargoed?
      Embargo.active?(@permissions&.embargo)
    end
end
