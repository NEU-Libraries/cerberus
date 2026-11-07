# frozen_string_literal: true

# Each Work's abstract by noid, for a list that already has its rows. One gated
# Solr query for the whole list. It only adds text: a Work the viewer may not
# discover simply has no abstract, and its row stays. See docs/edit-surfaces.md.
class WorkAbstracts < ApplicationService
  def initialize(scope:, noids:)
    @scope = scope
    @noids = Array(noids).map(&:to_s).uniq
    super()
  end

  def call
    return {} if @noids.empty?

    search.documents.each_with_object({}) do |doc, abstracts|
      abstract = Array(doc['description_tsim']).first.presence
      abstracts[Array(doc['alternate_ids_ssim']).first.to_s.delete_prefix('id-')] = abstract if abstract
    end
  end

  private

    # `with_filters`, never a merged `:fq`, which would drop the gated-discovery
    # clause. Same plumbing as WorkAssociations#search.
    def search
      terms = @noids.map { |noid| "id-#{noid}" }.join(',')
      builder = SearchBuilder.new(@scope)
                             .with({})
                             .with_filters("{!terms f=alternate_ids_ssim}#{terms}")
                             .merge(rows: @noids.size)
      Blacklight.default_index.search(params: builder)
    end
end
