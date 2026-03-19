# frozen_string_literal: true

FactoryBot.define do
  factory :load_report do
    status { :pending }
    source_filename { "test_archive.zip" }
    started_at { nil }
    finished_at { nil }
  end
end
