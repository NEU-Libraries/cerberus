module ApplicationHelper

  def thumbnail_for(core_record) 
    if core_record.thumbnail 
      return core_record.thumbnail 
    else
      return core_record.canonical.class.to_s
    end
  end
end
