# frozen_string_literal: true

# "Why this result?": reruns the search a result came from, narrowed to that
# one result, and asks Solr how it scored. Admins and delegated admins only,
# for their own understanding and to explain a result to a user in plain words.
# See docs/discovery.md ("Why this result?").
#
# Filters never change a score, so narrowing to the result by id leaves its
# score exactly as ranked on the page the admin was looking at.
class SearchExplanationsController < ApplicationController
  include Blacklight::Configurable
  # `search_service` lives in Searchable, not in Blacklight::Controller.
  include Blacklight::Searchable

  copy_blacklight_config_from(CatalogController)

  before_action :authenticate_user!
  before_action :require_admin_or_delegate

  layout false

  # Without the user here the gated search runs as anonymous, so a delegate's
  # result outside the public set would read as not found.
  def search_service_context
    { current_user: current_user, effective_user: effective_user }
  end

  def show
    @query = params[:q].to_s.strip.presence
    @sorted_by = params[:sort].presence
    return if @query.nil?

    @document = explained_document
    return if @document.nil?

    @explanation = SearchExplanation.new(@document.fetch('[explain]', nil))
    fields = @explanation.fields
    @rows = fields.zip(MatchedWords.call(document: @document, matches: fields.map(&:match), query: @query))
  end

  private

    def require_admin_or_delegate
      return if effective_user&.admin? || effective_user&.admin_delegate?

      render template: 'errors/forbidden', status: :forbidden, layout: 'application'
    end

    def explained_document
      fl = ['id', 'score', '[explain style=nl]', *MatchedWords::STORED].join(',')
      builder = search_service.search_builder.with(q: @query)
                              .with_filters(%(id:"#{params[:id].to_s.gsub(/["\\]/, '')}"))
                              .merge(rows: 1, hl: false, fl: fl)
      Blacklight.default_index.search(params: builder).documents.first
    end
end
