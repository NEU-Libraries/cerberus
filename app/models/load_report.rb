# frozen_string_literal: true

class LoadReport < ApplicationRecord
  has_many :xml_ingests, dependent: :destroy
  has_many :iptc_ingests, dependent: :destroy

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  def start_load
    update!(status: :processing, started_at: Time.current)
  end

  def finish_load
    update!(status: :completed, finished_at: Time.current)
  end

  def fail_load
    update!(status: :failed, finished_at: Time.current)
  end

  def total_ingests
    xml_ingests.count + iptc_ingests.count
  end

  def completed_ingests
    xml_ingests.completed.count + iptc_ingests.completed.count
  end

  def failed_ingests
    xml_ingests.failed.count + iptc_ingests.failed.count
  end
end
