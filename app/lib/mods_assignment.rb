# frozen_string_literal: true

module MODSAssignment
  def plain_title=(title_str)
    mods_obj = Mods::Record.new.from_str(mods_xml)
    mods_obj.title_info.find { |n| n.attribute('usage')&.value == 'primary' }.title.content = title_str
    self.mods_xml = mods_obj.to_xml
  end

  def plain_description=(desc_str)
    mods_obj = Mods::Record.new.from_str(mods_xml)
    mods_obj.abstract.first.content = desc_str
    self.mods_xml = mods_obj.to_xml
  end
end
