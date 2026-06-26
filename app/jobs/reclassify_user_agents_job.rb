# frozen_string_literal: true

# Re-scans the user_agents dimension against the current bot list
# (config.x.cerberus.impression_bots) and updates is_bot where the verdict
# changed. O(distinct UAs) — a tiny table — and monotonic-narrowing in practice
# (the list only grows, moving UAs human → bot). After this runs, the next
# RollupImpressionsJob window re-derives human counts with the new verdicts, so
# a bot-list edit retroactively re-cleans history with no raw mutation (§9).
# Scheduled daily.
class ReclassifyUserAgentsJob < ApplicationJob
  queue_as :background

  def perform
    UserAgent.find_each do |user_agent|
      verdict = UserAgent.bot?(user_agent.ua_string)
      next if user_agent.is_bot == verdict

      user_agent.update_columns(is_bot: verdict, classified_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
