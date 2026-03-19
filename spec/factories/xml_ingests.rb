# frozen_string_literal: true

FactoryBot.define do
  factory :xml_ingest do
    association :load_report
    status { :pending }
    work_pid { nil }
    source_filename { "record_001.xml" }
  end
end
