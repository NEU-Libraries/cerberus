# frozen_string_literal: true

module MODSToJson
  include MODSExtraction

  def convert_xml_to_json(raw_xml)
    mods_obj = Mods::Record.new.from_str(raw_xml)
    record = Metadata::MODS.new

    record.main_title = extract_main_title(mods_obj)

    # Creator/Contributor
    record.names = extract_plain_names(mods_obj)

    # Language
    record.languages = mods_obj.languages

    # Date created
    record.date_created = extract_date_created(mods_obj)

    # Type of resource
    record.resource_type = mods_obj.typeOfResource.text.squish

    # Genre
    record.genres = extract_genres(mods_obj)

    # Format
    record.resource_type = mods_obj.typeOfResource.text.squish
    record.format = mods_obj.physical_description.form.text.squish
    record.extent = mods_obj.physical_description.extent.text.squish

    # Digital origin
    record.digital_origin = mods_obj.physical_description.digitalOrigin.text.squish

    # Abstract/Description
    # This can have multiple entries, need to test
    record.abstract = mods_obj.abstract.text.squish

    # Related item
    record.related_series = extract_related_series(mods_obj)

    # Subjects and keywords
    record.topical_subjects = extract_topical_subjects(mods_obj)

    # Permanent URL
    record.identifiers = extract_identifiers(mods_obj)

    # Use and reproduction
    record.access_condition = mods_obj.accessCondition.text.squish

    record.json_attributes
  end

  private

    def safe_extract
      yield
    rescue NoMethodError
      ''
    end
end
