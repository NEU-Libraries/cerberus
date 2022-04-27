# frozen_string_literal: true

module Metadata
  class MODS < ApplicationRecord
    include AttrJson::Record

    # titles
    attr_json :main_title, Metadata::Fields::TitleInfo.to_type
    attr_json :uniform_title, :string
    attr_json :abbreviated_title, :string
    attr_json :alternative_title, :string
    attr_json :translated_title, :string

    attr_json :edition, :string
    attr_json :names, Metadata::Fields::Name.to_type, array: true
    attr_json :abstract, :string
    attr_json :description, :string
    attr_json :languages, :string, array: true
    attr_json :publication_information, :string

    # dates
    attr_json :date_issued, :datetime
    attr_json :date_created, :datetime
    attr_json :copyright_date, :datetime

    attr_json :resource_type, :string
    attr_json :genres, :string, array: true
    attr_json :format, :string
    attr_json :digital_origin, :string
    attr_json :extent, :string
    attr_json :notes, :string, array: true
    attr_json :map_data, :string

    # subjects
    attr_json :personal_name_subjects, :string, array: true
    attr_json :corporate_name_subjects, :string, array: true
    attr_json :temporal_subjects, :string, array: true
    attr_json :geographic_subjects, :string, array: true
    attr_json :topical_subjects, :string, array: true

    # related item
    attr_json :host_collections, :string, array: true
    attr_json :related_series, :string, array: true
    attr_json :location, :string

    # identifiers
    attr_json :identifiers, :string, array: true
    attr_json :permanent_url, :string

    # access
    attr_json :access_condition, :string
    attr_json :use_and_reproduction, :string
    attr_json :restriction_on_access, :string
  end
end
