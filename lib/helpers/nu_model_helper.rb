# Note that this assumes that you will implement 
# a nu_mods_datastream.rb in your object model 
# called 'mods.' 

module NuModelHelper 
  def title=(string)
    self.mods_title = string
    self.nu_title = string 
  end

  def title
    self.mods_title 
  end

  def identifier=(string)
    self.nu_identifier = string 
    self.mods_identifier = string 
  end

  def identifier
    self.mods_identifier 
  end

  def description=(string)
    self.nu_description = string 
    self.mods_abstract = string 
  end

  def description 
    self.mods_abstract 
  end

  def date_of_issue=(string) 
    self.mods_date_issued = string 
  end

  def date_of_issue
    self.mods_date_issued 
  end

  def keywords=(array_of_strings) 
    self.mods_keyword = array_of_strings 
  end

  def keywords 
    self.mods_keyword 
  end

  def corporate_creators=(array_of_strings) 
    self.mods_corporate_creators = array_of_strings
  end

  def corporate_creators
    self.mods_corporate_creators 
  end

  def personal_creators=(hash)
    first_names = hash['creator_first_names'] 
    last_names = hash['creator_last_names']  

    self.set_mods_personal_creators(first_names, last_names) 
  end

  def personal_creators 
    self.mods_personal_creators 
  end
end