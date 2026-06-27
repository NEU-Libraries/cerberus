# frozen_string_literal: true

module Authorizable
  extend ActiveSupport::Concern

  # Raised by the `authorize_*!` helpers when AtlasRb returns a nil
  # permissions envelope — Atlas's `/resources/:id/permissions` returns
  # a 200 with no `"resource"` key for unknown IDs, so atlas_rb's
  # pass-through unwrapping yields nil rather than raising. Translating
  # that into an explicit sentinel here means the same rescue_from path
  # handles both the JSON::ParserError shape (from `Resource.find`'s
  # empty-body 404) and the nil-permissions shape (from the downloads /
  # before_action route).
  class ResourceNotFound < StandardError; end

  class_methods do
    # Deny-by-default write gating for the standard REST resource
    # controllers (works / collections / communities). Declaring the
    # uniform "can this principal do this to this resource?" gates from
    # one place is the structural fix for the opt-in-per-action drift the
    # authorization audit found: a new resource controller that calls this
    # can't silently ship a write that's gated only at the GET form.
    #
    # Three gates, matching the policy:
    #   - authentication on the create surface (new/create). Cerberus has
    #     no :create ability — the role/parent decision is Atlas's — so
    #     this is the UX/defense-in-depth gate: a logged-out caller is
    #     redirected to sign in rather than bounced by an Atlas error.
    #   - the :edit ability on BOTH the edit form and the write that
    #     follows (edit/update), closing the "form gated, write open" gap.
    #   - the tombstone gate on tombstone.
    #
    # `extra_edit:` folds controller-specific edit-gated actions into the
    # :edit gate (Works' metadata / update_metadata tabs).
    def authorize_resource_writes!(extra_edit: [])
      # The filtered actions live in the including controller, not this concern,
      # so the lexical-scope cop can't see them — that indirection is the whole
      # point of the macro.
      # rubocop:disable Rails/LexicallyScopedActionFilter
      before_action :authenticate_user!,   only: %i[new create]
      before_action :authorize_edit!,      only: %i[edit update] + Array(extra_edit)
      before_action :authorize_tombstone!, only: %i[tombstone]
      # rubocop:enable Rails/LexicallyScopedActionFilter
    end
  end

  included do
    rescue_from CanCan::AccessDenied do
      render template: 'errors/forbidden', status: :forbidden
    end

    # Two flavours of "resource doesn't exist" land here:
    #
    #   1. `AtlasRb::Resource.find` (and its Work/Collection/Community
    #      siblings) call JSON.parse on Atlas's empty 404 body and the
    #      parser raises `unexpected end of input`.
    #   2. `AtlasRb::Resource.permissions` returns nil for unknown IDs;
    #      the `authorize_*!` helpers below raise `ResourceNotFound`
    #      in that case so we don't trip a `NoMethodError` on the nil.
    #
    # Both shapes render the same friendly 404 page rather than the
    # default Rails exception trace, with the singularized controller
    # name giving the template a sensible `obj_type` default
    # ("work" / "collection" / "community" / "download" / etc.).
    rescue_from JSON::ParserError, ResourceNotFound do
      render template: 'errors/not_found',
             status:   :not_found,
             locals:   { obj_type: controller_name.singularize }
    end
  end

  private

    def render_gone(record)
      render template: 'errors/gone', status: :gone, locals: { record: record }
    end

    # Translate an Atlas tombstone response into the right redirect + flash.
    #
    # The tombstone bindings return the raw Faraday::Response (atlas_rb does NOT
    # raise on the tombstone refusal — RaiseOnResourceError passes a 422 whose
    # body carries `code: "has_live_children"` straight through). Atlas refuses
    # with 422 when the resource still has live (non-tombstoned) members, so a
    # caller that ignores the response (the old `tombstone; redirect notice:` shape)
    # reports a false "deleted" while the resource stays live. This is guaranteed
    # for Communities: ShowcaseProvisioner seeds every Community with live
    # showcase Collections, so its tombstone is always refused.
    def perform_tombstone!(response, type:)
      if response.success?
        redirect_to root_path, notice: "#{type} deleted."
      elsif response.status == 422
        redirect_back_or_to(root_path, alert: "#{type} can't be deleted while it still contains live members. " \
                                              'Withdraw or move them first.')
      else
        redirect_back_or_to(root_path, alert: "#{type} could not be deleted.")
      end
    end

    def authorize_show!
      @permissions = AtlasRb::Resource.permissions(params[:id])
      raise ResourceNotFound if @permissions.nil?

      authorize! :read, solr_doc_from_permissions(@permissions)
    end

    def authorize_edit!
      authorize_edit_for!(params[:id])
    end

    # The :edit gate keyed on an explicit id rather than params[:id], so
    # callers whose resource id rides a different param can reuse it. The
    # XML editor needs this: `xml#editor` carries params[:id] while
    # `xml#validate`/`xml#update` carry params[:resource_id].
    def authorize_edit_for!(id)
      @permissions = AtlasRb::Resource.permissions(id)
      raise ResourceNotFound if @permissions.nil?

      authorize! :edit, solr_doc_from_permissions(@permissions)
    end

    def authorize_tombstone!
      @permissions = AtlasRb::Resource.permissions(params[:id])
      raise ResourceNotFound if @permissions.nil?

      authorize! :tombstone, solr_doc_from_permissions(@permissions, klass: tombstone_klass)
    end

    def tombstone_klass
      controller_name.classify
    end

    # Set the show-page affordance flags from the already-loaded @permissions,
    # so the Edit / Delete links render iff the action behind them would be
    # authorized (the same `:edit` / `:tombstone` gates `authorize_*!` enforce —
    # no showing a control the user can't use). Keeps each resource controller's
    # #show under the complexity budget and DRYs the shared computation.
    def assign_show_abilities!(klass:)
      doc = solr_doc_from_permissions(@permissions, klass: klass)
      @can_edit = current_ability.can?(:edit, doc)
      @can_tombstone = current_ability.can?(:tombstone, doc)
    end

    def solr_doc_from_permissions(permissions, klass: nil)
      SolrDocument.new(
        'read_access_group_ssim'  => permissions.read,
        'edit_access_group_ssim'  => permissions.edit,
        'internal_resource_tesim' => klass.to_s,
        'depositor_ssi'           => permissions.try(:depositor),
        'proxy_uploader_ssi'      => permissions.try(:proxy_uploader)
      )
    end
end
