# frozen_string_literal: true

module MODSAssignment
  def plain_title=(title_str)
    # if title_info not available, need to be able to make from template
    # mods.xpath('//mods:titleInfo[@usage = "primary"]/mods:title//text()').first.content = "Hats"
    mods_obj.title_info.title.children.first.content = title_str
  end

  def plain_description=(desc_str)
    # if abstract not available, need to be able to make from template
    # mods.xpath('//mods:abstract//text()').first.content = desc_str
    mods_obj.abstract.first.content = desc_str
  end
end
