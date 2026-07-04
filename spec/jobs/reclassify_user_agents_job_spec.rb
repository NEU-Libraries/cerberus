# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReclassifyUserAgentsJob do
  it 'updates is_bot only where the current bot-list verdict changed' do
    mislabelled_human = UserAgent.create!(ua_string: 'Mozilla/5.0', is_bot: true,  classified_at: 1.day.ago)
    mislabelled_bot   = UserAgent.create!(ua_string: 'Googlebot',   is_bot: false, classified_at: 1.day.ago)
    stable_bot        = UserAgent.create!(ua_string: 'curl/8.4.0',  is_bot: true,  classified_at: 1.day.ago)

    described_class.perform_now

    expect(mislabelled_human.reload.is_bot).to be(false) # 'Mozilla/5.0' matches no substring
    expect(mislabelled_bot.reload.is_bot).to be(true)    # 'Googlebot' contains 'bot'
    expect(stable_bot.reload.is_bot).to be(true)         # 'curl' still on the list
  end
end
