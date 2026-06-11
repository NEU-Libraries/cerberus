# frozen_string_literal: true

FactoryBot.define do
  factory :multipage_ingest do
    association :load_report
    status { :pending }
    work_pid { nil }
    sequence(:sequence) { |n| n }
    source_filename { 'page_001.tif' }
  end
end
