# frozen_string_literal: true

# Deleting a Collection or Community that still holds items: everything live
# beneath it is withdrawn with it, by TombstoneCascadeJob. See docs/admin.md
# ("Deleting a container that is not empty").
#
# Every check the confirmation makes in the browser is made again here, since a
# form can be posted without it.
module CascadeTombstoning
  extend ActiveSupport::Concern

  included do
    helper_method :cascade_delete_allowed?, :cascade_title_matches?
  end

  private

    # The confirmation's counts, prepared only for someone it is offered to.
    # TombstoneTargets queries lazily, so nobody else pays for it.
    def offer_cascade_delete
      return unless container_holds_items? && @can_tombstone && cascade_delete_allowed?

      container = @collection || @community
      @cascade_targets = TombstoneTargets.new(noid: params[:id], uuid: container.valkyrie_id)
    end

    # The show page's own test of emptiness: a community's empty showcases are
    # hidden from its listing yet still block a plain delete, so it asks
    # @deletable; a collection lists everything it holds.
    def container_holds_items?
      instance_variable_defined?(:@deletable) ? !@deletable : @response.documents.any?
    end

    def perform_cascade_tombstone!
      return render(template: 'errors/forbidden', status: :forbidden) unless cascade_delete_allowed?

      container = require_resource!(atlas_class.find(params[:id]))
      targets = TombstoneTargets.new(noid: params[:id], uuid: container.valkyrie_id)
      refusal = cascade_refusal(container, targets)
      return redirect_back_or_to(resource_path(solr_type, params[:id]), alert: refusal) if refusal

      enqueue_cascade(container, targets)
    end

    def enqueue_cascade(container, targets)
      title = helpers.plain_text(container.title)
      TombstoneCascadeJob.perform_later(noid: params[:id], uuid: container.valkyrie_id, klass: solr_type,
                                        title: title, reason: removal_reason)
      redirect_to parent_path(params[:id]),
                  notice: "Deleting “#{title}” and the #{targets.total} items in it. " \
                          'Requests & activity records each one when it finishes.'
    end

    # A community holds other people's collections and showcases, so only an
    # admin may withdraw one whole. The delegated tier may withdraw a collection.
    def cascade_delete_allowed?
      return false if effective_user.nil?
      return effective_user.admin? if solr_type == 'Community'

      effective_user.admin? || effective_user.admin_delegate?
    end

    # Formatting and spacing do not count: a title can carry sub- and
    # superscript markup that nobody types.
    def cascade_title_matches?(typed, title)
      normalized = ->(value) { helpers.plain_text(value).squish }
      typed.present? && normalized.call(typed) == normalized.call(title)
    end

    def cascade_refusal(container, targets)
      if !cascade_title_matches?(params[:confirm_title], container.title)
        'Type the title exactly to confirm the deletion. Nothing was deleted.'
      elsif removal_reason.blank?
        'Choose a reason for removal. Nothing was deleted.'
      elsif targets.over_limit?
        "This holds more than #{TombstoneTargets::LIMIT} items. Ask the development team to delete it. " \
          'Nothing was deleted.'
      end
    end
end
