# frozen_string_literal: true

# Formatting for the My DRS multi-account switcher. The panel's one considered
# element is the GROUP DIFF — what a person would gain or lose by switching to
# another of their accounts — so the "reason to switch" reads at a glance
# instead of as two long raw group lists.
module AccountsHelper
  # How many gained/lost groups to list before collapsing into a "+N more" chip.
  # A real account can hold ~180 groups, so an unbounded diff would swamp the row.
  ACCOUNT_DIFF_CAP = 40

  # The account the caller is currently acting as, taken from the same accounts
  # list the panel renders so the group baseline is internally consistent.
  def current_account(accounts)
    accounts.find { |account| account['email'] == current_user&.email }
  end

  # Groups an account would GAIN and LOSE relative to the currently-acting one,
  # as cosmetic names, sorted. Reuses pretty_group_name (the view-side cosmetic
  # lookup) so labels read the same as everywhere else.
  def account_group_diff(account, current_groups)
    account_groups = Array(account['groups'])
    {
      gained: (account_groups - current_groups).map { |raw| pretty_group_name(raw) }.sort,
      lost:   (current_groups - account_groups).map { |raw| pretty_group_name(raw) }.sort
    }
  end

  # Split a diff list into the chips to show and the overflow count.
  def account_diff_chips(names)
    [names.first(ACCOUNT_DIFF_CAP), [names.size - ACCOUNT_DIFF_CAP, 0].max]
  end
end
