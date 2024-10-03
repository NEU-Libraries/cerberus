# frozen_string_literal: true

class LoadReport < ApplicationRecord
  has_many :ingests

  enum status: { in_progress: 0, completed: 1, failed: 2 }

  validates :status, presence: true

  def start_load
    update(status: :in_progress, started_at: Time.now)
  end

  def finish_load
    update(status: :completed, finished_at: Time.now)
  end

  def fail_load
    update(status: :failed, finished_at: Time.now)
  end

  def success_rate
    return 0 if ingests.empty?
    ((ingests.completed.count.to_f / ingests.count.to_f) * 100).round(2)
  end
end
