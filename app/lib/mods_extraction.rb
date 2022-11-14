# frozen_string_literal: true

module MODSExtraction
  def extract_main_title(mods_obj)
    { non_sort: mods_obj.title_info.nonSort.text.squish,
      subtitle: mods_obj.title_info.subTitle.text.squish,
      title: mods_obj.title_info.title.text.squish,
      part_name: mods_obj.title_info.partName.text.squish,
      part_number: mods_obj.title_info.partNumber.text.squish }
  end

  def extract_plain_names(mods_obj)
    names = []
    mods_obj.plain_name.each do |pn|
      names << { name: pn.display_value_w_date,
                 role: pn.role.value&.first }
    end
    names
  end

  def extract_date_created(mods_obj)
    return if mods_obj.origin_info.as_object.first.blank?

    safe_date_parse(
      mods_obj
      .origin_info
      .as_object.first
      .key_dates.select do |d|
        d.name == 'dateCreated'
      end.first.text.squish
    )
  end

  def extract_genres(mods_obj)
    result = []
    mods_obj.genre.each do |g|
      result << g.text.squish
    end
    result
  end

  def extract_related_series(mods_obj)
    result = []
    mods_obj.related_item.each do |ri|
      result << ri.titleInfo.title.text.squish if ri.type_at == 'series'
    end
    result
  end

  def extract_topical_subjects(mods_obj)
    result = []
    mods_obj.subject.topic.each do |t|
      result << t.text.squish
    end
    result
  end

  def extract_identifiers(mods_obj)
    result = []
    mods_obj.identifier.each do |i|
      result << i.text.squish
    end
    result
  end

  private

    def safe_date_parse(str)
      DateTime.parse(str)
    rescue Date::Error
      ''
    end
end
