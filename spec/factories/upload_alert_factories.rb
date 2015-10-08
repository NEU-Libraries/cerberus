FactoryGirl.define do
  factory :upload_alert, class: UploadAlert do
    sequence(:title)            { |n| "Upload #{n}" }
    sequence(:depositor_email)  { |n| "#{n}@example.com" }
    sequence(:depositor_name)   { |n| "Person #{n}" }
    sequence(:pid)              { |n| "000#{n}" }
    sequence(:collection_title) { |n| "Example Collection Title" }
    sequence(:collection_pid)   { |n| "001#{n}" }

    change_type :create

    trait :notified do
      notified true
    end

    trait :update do
      change_type :update
    end

    factory :theses_alert do
      content_type "Theses and Dissertations"

      factory :theses_notified_alert do
        notified
      end

      factory :theses_update_alert do
        update
      end
    end

    factory :research_alert do
      content_type "Research Publications"

      factory :research_notified_alert do
        notified
      end

      factory :research_update_alert do
        update
      end
    end

    factory :monograph_alert do
      content_type "Monographs"

      factory :monograph_notified_alert do
        notified
      end

      factory :monograph_update_alert do
        update
      end
    end

    factory :presentation_alert do
      content_type "Presentations"

      factory :presentation_notified_alert do
        notified
      end

      factory :presentation_update_alert do
        update
      end
    end

    factory :dataset_alert do
      content_type "Datasets"

      factory :dataset_notified_alert do
        notified
      end

      factory :dataset_update_alert do
        update
      end
    end

    factory :learning_object_alert do
      content_type "Learning Objects"

      factory :learning_object_notified_alert do
        notified
      end

      factory :learning_object_update_alert do
        update
      end
    end

    factory :other_pub_alert do
      content_type "Other Publications"

      factory :other_pub_notified_alert do
        notified
      end

      factory :other_pub_update_alert do
        update
      end
    end

    factory :nonfeatured_alert do
      content_type ""

      factory :nonfeatured_notified_alert do
        notified
      end

      factory :nonfeatured_update_alert do
        update
      end
    end

    factory :collection_alert do
      content_type "collection"

      factory :collection_notified_alert do
        notified
      end

      factory :collection_update_alert do
        update
      end
    end
  end
end
