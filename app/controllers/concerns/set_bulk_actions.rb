# frozen_string_literal: true

# The Set edit page's two bulk actions, and the Sentinel authoring that feeds
# one of them.
#
# Both sweeps write the Set's *Works*, not the Set, so neither is governed by
# who may curate the recipe: a grantee with edit on a Set can add a collection
# holding fifty thousand Works they have no say over. They are operator-only
# (full admin or the devolved tier), and Atlas re-checks every per-Work write
# regardless — this gate decides who is offered the button.
#
# The two actions are deliberately asymmetric in what they promise. Privatize
# takes access away and is safe to offer broadly within that tier; there is no
# bulk publicize to match it, because a one-click widening across a whole Set is
# a disclosure foot-gun with no comparable use case. The tab is named so it does
# not imply the inverse exists.
module SetBulkActions
  extend ActiveSupport::Concern

  included do
    # The view renders the two tabs on the same predicate the write path gates
    # on, so a tab and its pane cannot disagree about who may use it.
    helper_method :bulk_operator?, :sentinel_groups
  end

  # `require_bulk_operator` is deliberately NOT registered here. A concern's
  # `included do` runs at include time, which puts its callbacks ahead of every
  # before_action the class declares below the include — so gating here answered
  # an anonymous POST with 403 Forbidden instead of sending it to sign in. The
  # controller declares it alongside its other gates, where the order is visible.

  # Whether this viewer may run a bulk action. The operator tier, not the Set's
  # own ACL — see the module comment.
  def bulk_operator?
    current_user&.admin? || current_user&.admin_delegate?
  end

  # The groups the ladder offers to restrict a tier to.
  #
  # Every group, not the acting user's own memberships. That looks like it
  # diverges from PermissionsForm#groups_for_permissions_picker, but it is the
  # same rule with the other branch removed: that helper hands the full list to
  # an admin or devolved admin and falls back to personal memberships for
  # everyone else, and everyone else cannot reach this tab at all.
  def sentinel_groups
    Group.for_select
  end

  # Upsert this Set's derivative-access policy (its Sentinel).
  #
  # Unlike the Collection tab, no container ceiling is handed to the record. A
  # Collection's ACL governs the Works inside it, so a tier more visible than
  # the Collection is incoherent on its face; a Set's ACL governs only who may
  # see the *Set object*, and its Works keep whatever visibility they had before
  # anyone curated them in. The ceiling that matters here is each Work's own,
  # which is per-Work and therefore applied at sweep time (SetSentinelApplyJob
  # clamps) rather than at authoring time. Monotonicity still holds — that is a
  # property of the ladder, not of any container.
  def sentinel
    record = Sentinel.find_or_initialize_by(target_id: params[:id])
    record.policy = sentinel_policy_from_params

    return render_rejected_set_sentinel(record) unless record.save

    redirect_to edit_set_path(params[:id], anchor: 'derivative-access'),
                notice: 'Derivative access saved. Apply it to sweep the works already in this set.'
  end

  # Enqueue the derivative-access sweep over the Works the Set denotes.
  def apply_sentinel
    if Sentinel.find_by(target_id: params[:id]).nil?
      return redirect_to edit_set_path(params[:id], anchor: 'derivative-access'),
                         alert: 'Save a derivative access policy before applying it.'
    end

    SetSentinelApplyJob.perform_later(set_noid: params[:id])
    redirect_to edit_set_path(params[:id], anchor: 'derivative-access'),
                notice: 'Applying derivative access to this set’s works. You’ll get a message when it finishes.'
  end

  # Enqueue the privatize sweep over the Works the Set denotes.
  def privatize
    SetPrivatizeJob.perform_later(set_noid: params[:id])
    redirect_to edit_set_path(params[:id], anchor: 'visibility'),
                notice: 'Making this set’s works private. You’ll get a message when it finishes.'
  end

  private

    # Full admins and the devolved tier only. Deliberately not @owned: owning a
    # Set says nothing about the Works a recipe reaches.
    def require_bulk_operator
      return if bulk_operator?

      render template: 'errors/forbidden', status: :forbidden
    end

    # Re-render the tab holding the policy that was SUBMITTED, not the stored
    # one — a refusal that redirects discards every selection the curator made,
    # and the ladder rules are exactly where seeing your own choices is the
    # point. Naming the pane server-side is the only way the tab holds: Turbo
    # follows a redirect with fetch, and the Fetch spec strips the fragment from
    # the resolved URL.
    def render_rejected_set_sentinel(record)
      prepare_sharing_form if @owned
      edit_breadcrumbs
      @sentinel = record
      @open_tab = 'derivative-access'
      flash.now[:alert] = record.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end

    # Build the per-tier policy from the ladder form.
    #
    # The "no added restriction" mode omits the tier rather than writing
    # ['public'], which is the Collection tab's behaviour on a *private*
    # collection and is the only coherent choice for a Set: an omitted tier rides
    # each Work's own visibility at apply time, so one policy can span a Set that
    # mixes public and restricted Works. Claiming ['public'] instead would be
    # refused on every private Work in the sweep.
    def sentinel_policy_from_params
      tier_schema = Sentinel::TIERS.index_with { [:mode, { groups: [] }] }
      permitted = params.fetch(:sentinel, {}).permit(tier_schema)

      Sentinel::TIERS.each_with_object({}) do |tier, policy|
        entry = permitted[tier]
        next if entry.blank? || entry[:mode] != 'restrict'

        policy[tier] = Array(entry[:groups]).compact_blank
      end
    end
end
