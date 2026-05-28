# frozen_string_literal: true

class LoadReport < ApplicationRecord
  belongs_to :loader, optional: true
  has_many :xml_ingests, dependent: :destroy
  has_many :iptc_ingests, dependent: :destroy

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3, completed_with_warnings: 4 }

  def start_load
    update!(status: :processing, started_at: Time.current)
  end

  def finish_load
    update!(status: :completed, finished_at: Time.current)
  end

  def finish_with_warnings
    update!(status: :completed_with_warnings, finished_at: Time.current)
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

  def warning_ingests
    xml_ingests.completed_with_warnings.count + iptc_ingests.completed_with_warnings.count
  end

  def failed_ingests
    xml_ingests.failed.count + iptc_ingests.failed.count
  end

  def maybe_finalize!
    with_lock do
      return if iptc_ingests.where(status: %i[pending processing]).exists? ||
                xml_ingests.where(status: %i[pending processing]).exists?

      if iptc_ingests.failed.exists? || xml_ingests.failed.exists?
        fail_load
      elsif iptc_ingests.completed_with_warnings.exists? ||
            xml_ingests.completed_with_warnings.exists?
        finish_with_warnings
      else
        finish_load
      end
    end
  end
end
