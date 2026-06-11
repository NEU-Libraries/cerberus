# frozen_string_literal: true

FactoryBot.define do
  factory :loader do
    sequence(:slug) { |n| "loader-#{n}" }
    display_name    { 'Test Loader' }
    group           { 'northeastern:drs:repository:loaders:test' }
    root_collection { 'neu:root' }
    kind            { :iptc }

    trait :xml do
      kind { :xml }
    end

    trait :multipage do
      kind { :multipage }
    end
  end
end
