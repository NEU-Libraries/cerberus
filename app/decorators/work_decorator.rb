# frozen_string_literal: true

module WorkDecorator
  def mods
    begin
      Metadata::Mods.find(mods_id)
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  def link
    link_to mods&.resource_type, 'google.com'
  end
end
