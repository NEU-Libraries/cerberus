# frozen_string_literal: true

# Reads a Work's health grade from Atlas, and turns a failed read into a reason
# the page can say inline. See docs/work-health.md.
class WorkHealthCheck
  # `report` is Atlas's answer, or nil when `failure` names why there is none.
  # `outage` is the capability lost, set only when `failure` is :outage.
  Result = Data.define(:report, :failure, :outage) do
    def ok? = !report.nil?
  end

  def self.call(id, nuid:)
    report = AtlasRb::Work.health_check(id, nuid: nuid)
    return Result.new(report: nil, failure: :not_found, outage: nil) if report.nil?

    Result.new(report: report, failure: nil, outage: nil)
  rescue AtlasRb::ResourceError, AtlasRb::BackendUnavailableError, Faraday::Error => e
    failed(e)
  end

  def self.failed(error)
    Rails.logger.warn("[work_health] #{error.class}: #{error.message}")
    outage = Outage.for(error)
    failure = if outage then :outage
              elsif error.is_a?(AtlasRb::ResourceError) && error.status == 403 then :forbidden
              else :failed
              end
    Result.new(report: nil, failure: failure, outage: outage)
  end
  private_class_method :failed
end
