# frozen_string_literal: true

FactoryBot.define do
  factory :iptc_ingest do
    association :load_report
    status { :pending }
    work_pid { nil }
    source_filename { "image_001.jpg" }
  end
end
