# frozen_string_literal: true

require 'rails_helper'

describe Metadata::MODS do
  describe 'attribute definitions' do
    let(:mods_class) { described_class }

    def assert_attr_json(attr_name, expected_type, array: false)
      attribute = mods_class.attr_json_registry.fetch(attr_name)
      expect(attribute).not_to be_nil

      if array
        expect(attribute.type).to be_a(AttrJson::Type::Array)
        expect(attribute.type.base_type).to be_a(expected_type)
      else
        expect(attribute.type).to be_a(expected_type)
      end
    end

    context 'titles' do
      it 'defines title attributes' do
        assert_attr_json(:main_title, AttrJson::Type::Model)
        assert_attr_json(:uniform_title, ActiveModel::Type::String)
        assert_attr_json(:abbreviated_title, ActiveModel::Type::String)
        assert_attr_json(:alternative_title, ActiveModel::Type::String)
        assert_attr_json(:translated_title, ActiveModel::Type::String)
      end
    end

    context 'single-value attributes' do
      it 'defines single-value attributes' do
        single_value_attrs = %i[edition abstract description publication_information
                                resource_type format digital_origin extent map_data
                                location permanent_url access_condition
                                use_and_reproduction restriction_on_access]

        single_value_attrs.each do |attr|
          assert_attr_json(attr, ActiveModel::Type::String)
        end
      end
    end

    context 'array attributes' do
      it 'defines array attributes' do
        assert_attr_json(:names, AttrJson::Type::Model, array: true)

        string_array_attrs = %i[languages genres notes personal_name_subjects
                                corporate_name_subjects temporal_subjects
                                geographic_subjects topical_subjects host_collections
                                related_series identifiers]

        string_array_attrs.each do |attr|
          assert_attr_json(attr, ActiveModel::Type::String, array: true)
        end
      end
    end

    context 'date attributes' do
      it 'defines date attributes' do
        date_attrs = %i[date_issued date_created copyright_date]

        date_attrs.each do |attr|
          assert_attr_json(attr, ActiveRecord::ConnectionAdapters::PostgreSQL::OID::DateTime)
        end
      end
    end
  end
end
