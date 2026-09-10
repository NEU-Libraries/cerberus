# frozen_string_literal: true

# The Set edit page's two bulk actions. Both sweep the Set's *Works*, not the
# Set, so they gate on the operator tier and never on the Set's own ACL: a
# grantee with edit on a Set can add a collection holding fifty thousand Works
# they have no say over. See docs/sets.md.
module SetBulkActions
  extend ActiveSupport::Concern

  included do
    helper_method :bulk_operator?, :sentinel_groups
  end

  # `require_bulk_operator` is deliberately NOT registered here: a concern's
  # `included do` puts its callbacks ahead of every before_action the class
  # declares below the include, so gating here answered an anonymous POST with
  # 403 Forbidden instead of sending it to sign in.

  def bulk_operator?
    current_user&.admin? || current_user&.admin_delegate?
  end

  def sentinel_groups
    Group.for_select
  end

  def sentinel
    record = Sentinel.find_or_initialize_by(target_id: params[:id])
    record.policy = sentinel_policy_from_params

    return render_rejected_set_sentinel(record) unless record.save

    redirect_to edit_set_path(params[:id], tab: 'derivative-access'),
                notice: 'Derivative access saved. Apply it to sweep the works already in this set.'
  end

  def apply_sentinel
    if Sentinel.find_by(target_id: params[:id]).nil?
      return redirect_to edit_set_path(params[:id], tab: 'derivative-access'),
                         alert: 'Save a derivative access policy before applying it.'
    end

    SetSentinelApplyJob.perform_later(set_noid: params[:id])
    redirect_to edit_set_path(params[:id], tab: 'derivative-access'),
                notice: 'Applying derivative access to this set’s works. You’ll get a message when it finishes.'
  end

  def privatize
    SetPrivatizeJob.perform_later(set_noid: params[:id])
    redirect_to edit_set_path(params[:id], tab: 'visibility'),
                notice: 'Making this set’s works private. You’ll get a message when it finishes.'
  end

  private

    # Deliberately not @owned: owning a Set says nothing about the Works a
    # recipe reaches.
    def require_bulk_operator
      return if bulk_operator?

      render template: 'errors/forbidden', status: :forbidden
    end

    # Re-render the SUBMITTED policy, not the stored one, and name the pane
    # server-side: a redirect discards every selection the curator made, and
    # Turbo follows one with fetch, which strips the fragment from the URL.
    def render_rejected_set_sentinel(record)
      prepare_sharing_form if @owned
      edit_breadcrumbs
      @sentinel = record
      @open_tab = 'derivative-access'
      flash.now[:alert] = record.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end

    # "No added restriction" omits the tier rather than writing ['public']: an
    # omitted tier rides each Work's own visibility at apply time, and claiming
    # ['public'] is refused on every private Work in the sweep.
    def sentinel_policy_from_params
      tier_schema = Sentinel::TIERS.index_with { [:mode, { groups: [] }] }
      permitted = params.fetch(:sentinel, {}).permit(tier_schema)

      Sentinel::TIERS.each_with_object({}) do |tier, policy|
        entry = permitted[tier]
        next if entry.blank? || entry[:mode] != 'restrict'

        # Committed rows and the entry row share one field name, so `uniq` keeps
        # a group named twice from reaching Atlas twice.
        policy[tier] = Array(entry[:groups]).compact_blank.uniq
      end
    end
end
