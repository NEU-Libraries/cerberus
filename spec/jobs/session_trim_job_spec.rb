# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionTrimJob do
  let(:model) { ActiveRecord::SessionStore::Session }

  # insert_all bypasses the SessionStore model's marshaling save path and lets
  # us pin updated_at (what the job filters on) directly.
  def session_aged(session_id, age)
    t = age.ago
    # rubocop:disable Rails/SkipsModelValidations -- deliberate: skip the SessionStore marshaling save
    model.insert_all([{ session_id: session_id, data: '', created_at: t, updated_at: t }])
    # rubocop:enable Rails/SkipsModelValidations
    model.find_by!(session_id: session_id)
  end

  after { model.delete_all }

  it 'deletes sessions idle longer than the TTL and keeps recent ones' do
    stale  = session_aged('stale', 3.weeks)
    recent = session_aged('recent', 1.day)

    described_class.perform_now

    expect(model.exists?(stale.id)).to be(false)
    expect(model.exists?(recent.id)).to be(true)
  end

  it 'honours an explicit ttl' do
    edge = session_aged('edge', 3.days)

    described_class.perform_now(ttl: 1.day)

    expect(model.exists?(edge.id)).to be(false)
  end
end
