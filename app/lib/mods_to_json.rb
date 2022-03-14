# frozen_string_literal: true

module ModsToJson
  def convert_xml_to_json(raw_xml, mods_record_id)
    mods_obj = Mods::Record.new.from_str(raw_xml)
    record = Metadata::Mods.find(mods_record_id)

    record.main_title = { non_sort: mods_obj.title_info.nonSort.text.squish,
                          subtitle: mods_obj.title_info.subTitle.text.squish,
                          title: mods_obj.title_info.title.text.squish,
                          part_name: mods_obj.title_info.partName.text.squish,
                          part_number: mods_obj.title_info.partNumber.text.squish }

    # Creator/Contributor
    names = []
    mods_obj.plain_name.each do |pn|
      names << { name: pn.display_value_w_date,
                 role: pn.role.value.first }
    end
    record.names = names

    # Language
    record.languages = mods_obj.languages

    # Date created
    record.date_created = DateTime.parse(
      mods_obj
      .origin_info
      .as_object.first
      .key_dates.select do |d|
        d.name == 'dateCreated'
      end.first.text.squish
    )

    # Type of resource
    record.resource_type = mods_obj.typeOfResource.text.squish

    # Genre
    record.genres = []
    mods_obj.genre.each do |g|
      record.genres << g.text.squish
    end

    # Format
    record.resource_type = mods_obj.typeOfResource.first.text.squish
    record.format = mods_obj.physical_description.form.text.squish
    record.extent = mods_obj.physical_description.extent.text.squish

    # Digital origin
    record.digital_origin = mods_obj.physical_description.digitalOrigin.text.squish

    # Abstract/Description
    # This can have multiple entries, need to test
    record.abstract = mods_obj.abstract.text.squish

    # Related item
    record.related_series = []
    mods_obj.related_item.each do |ri|
      record.related_series << ri.titleInfo.title.text.squish if ri.type_at == 'series'
    end

    # Subjects and keywords
    record.topical_subjects = []
    mods_obj.subject.topic.each do |t|
      record.topical_subjects << t.text.squish
    end

    # Permanent URL
    record.identifiers = []
    mods_obj.identifier.each do |i|
      record.identifiers << i.text.squish
    end

    # Use and reproduction
    record.access_condition = mods_obj.accessCondition.text.squish

    record.save!
  end
end
