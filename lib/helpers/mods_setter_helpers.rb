# Note that this assumes that you will implement 
# a nu_mods_datastream.rb in your object model 
# called 'mods.' 

module ModsSetterHelpers 
  def mods_title=(title) 
    mods.mods_title_info.mods_title = title 
  end

  def mods_title 
    mods.mods_title_info.mods_title[0]
  end

  def mods_abstract=(abstract) 
    mods.mods_abstract = abstract 
  end

  def mods_abstract
    mods.mods_abstract[0]
  end

  def mods_keyword=(array_of_keywords)
    array_of_keywords.select! { |keyword| !keyword.blank? } 
    mods.mods_subject.mods_keyword = array_of_keywords 
  end

  def mods_keyword
    mods.mods_subject[0].mods_keyword 
  end

  def mods_corporate_creators=(creators) 
    mods.assign_corporate_names(creators) 
  end

  def mods_corporate_creators
    mods.mods_corporate_name 
  end

  def mods_identifier=(id)
    mods.mods_identifier = id 
  end

  def mods_identifier 
    mods.mods_identifier[0] 
  end

  def mods_date_issued=(date) 
    mods.mods_origin_info.mods_date_issued = date 
  end

  def mods_date_issued
    mods.mods_origin_info(0).mods_date_issued[0] 
  end

  # Should return [{first: "Will", last: "Jackson"}, {first: "next_first", last: "etc"}]
  def mods_personal_creators 
    result_array = []

    first_names = mods.mods_personal_name.mods_first_name 
    last_names = mods.mods_personal_name.mods_last_name 

    names = first_names.zip(last_names) 

    # NB: When accessing nested arrays of form [[first, second], [first, second]]
    # that are all of even length, array.each do |first, second| grabs both elements 
    # out of each nested array in sequence.  Did not know this until I looked it up. 
    names.each do |first, last| 
      result_array << Hash[first: first, last: last] 
    end

    return result_array 
  end 

  def mods_collection=(val) 
    mods.mods_type_of_resource.mods_collection = val 
  end
end