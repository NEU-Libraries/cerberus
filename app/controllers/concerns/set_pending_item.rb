# frozen_string_literal: true

# The item an Add-to-set picker's "New set" link was opened for. The link
# carries it, and the page it came from, through the new-set form, so the set
# is created already holding it and the user lands back where they were.
module SetPendingItem
  extend ActiveSupport::Concern

  private

    # url_from drops an off-host return_to, so it cannot become an open redirect.
    def pending_item
      kind = %w[work collection].find { |k| params[:"#{k}_id"].present? }
      return if kind.nil?

      { kind: kind, noid: params[:"#{kind}_id"], return_to: url_from(params[:return_to]) }
    end

    # The set exists by now, so a refused add must not read as a failed create:
    # it lands on the new set with the reason.
    def add_pending_item(set)
      if @pending[:kind] == 'collection'
        AtlasRb::Compilation.add_included_collection(set['id'], @pending[:noid])
      else
        AtlasRb::Compilation.add_included_work(set['id'], @pending[:noid])
      end
      redirect_to @pending[:return_to] || set_path(set['id']),
                  notice: "Set “#{set['title']}” created, with the #{@pending[:kind]} added to it."
    rescue AtlasRb::CompilationError => e
      redirect_to set_path(set['id']), alert: "Set created, but the #{@pending[:kind]} was not added: #{e.message}"
    end
end
